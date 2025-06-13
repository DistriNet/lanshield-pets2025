package com.example.mdns


import android.net.wifi.WifiManager
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.findNavController
import androidx.navigation.ui.AppBarConfiguration
import androidx.navigation.ui.navigateUp
import com.example.mdns.databinding.ActivityMainBinding
import java.net.InetAddress
import java.net.MulticastSocket
import java.net.DatagramPacket
import java.net.DatagramSocket

class MainActivity : AppCompatActivity() {

    private lateinit var appBarConfiguration: AppBarConfiguration
    private lateinit var binding: ActivityMainBinding
    val TAG = "TAG"

    private lateinit var multicastLock: WifiManager.MulticastLock
    private val mdnsAddress = "224.0.0.251"
    private val mDnsGroup = InetAddress.getByName(mdnsAddress)
    private val mdnsPort = 5353
    private lateinit var socket: MulticastSocket
    private lateinit var nsdHelper: NsdHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)


        val editTextInput = findViewById<EditText>(R.id.editTextInput)
        val buttonSubmit = findViewById<Button>(R.id.buttonSubmit)
        val buttonStop = findViewById<Button>(R.id.buttonStop)
        val implementationTypes: Spinner = findViewById(R.id.spinner)
        val serviceTypes: Spinner = findViewById(R.id.spinner2)



        // Set up button click listener
        buttonSubmit.setOnClickListener {
            socket = MulticastSocket(mdnsPort)
            socket.timeToLive = 255
            socket.joinGroup(mDnsGroup)
            GlobalData.expectedHostname = editTextInput.text.toString() // Get text from EditText

            nsdHelper = NsdHelper(this, socket)
            nsdHelper.initializeNsd()

            discoverServices()
            buttonStop.isEnabled = true
            buttonSubmit.isEnabled = false
        }

        buttonStop.setOnClickListener {
            nsdHelper.tearDown()
            buttonStop.isEnabled = false
            buttonSubmit.isEnabled = true
        }
        // Create an ArrayAdapter using the string array and a default spinner layout.
        ArrayAdapter.createFromResource(
            this,
            R.array.implementations_array,
            android.R.layout.simple_spinner_item
        ).also { adapter ->
            // Specify the layout to use when the list of choices appears.
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            // Apply the adapter to the spinner.
            implementationTypes.adapter = adapter
        }
        ArrayAdapter.createFromResource(
            this,
            R.array.service_types,
            android.R.layout.simple_spinner_item
        ).also { adapter ->
            // Specify the layout to use when the list of choices appears.
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            // Apply the adapter to the spinner.
            serviceTypes.adapter = adapter
        }
        serviceTypes.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: AdapterView<*>?,
                view: View?,
                position: Int,
                id: Long
            ) {
                // Handle item selection
                val selectedItem = parent?.getItemAtPosition(position).toString()
                GlobalData.serviceType = selectedItem
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Handle no selection case if necessary
            }
        }
        implementationTypes.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: AdapterView<*>?,
                view: View?,
                position: Int,
                id: Long
            ) {
                // Handle item selection
                val selectedItem = parent?.getItemAtPosition(position).toString()
                GlobalData.implementationType = selectedItem
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {
                // Handle no selection case if necessary
            }
        }
//        val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
//        multicastLock = wifiManager.createMulticastLock("mdnsLock")
//        multicastLock.setReferenceCounted(true)
//        multicastLock.acquire()

    }

    private fun discoverServices() {
        try {
            nsdHelper.discoverServices()
            Log.d("MainActivity", "Started discovering services")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to discover services: ${e.message}")
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        // Inflate the menu; this adds items to the action bar if it is present.
        menuInflater.inflate(R.menu.menu_main, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        return when (item.itemId) {
            R.id.action_settings -> true
            else -> super.onOptionsItemSelected(item)
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        val navController = findNavController(R.id.nav_host_fragment_content_main)
        return navController.navigateUp(appBarConfiguration)
                || super.onSupportNavigateUp()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up by unregistering the service
        nsdHelper.tearDown()
        multicastLock.release()
    }
}