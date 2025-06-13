package com.example.mdns

import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.nio.ByteBuffer

class MDNSHelper {
    companion object {

        fun getIPv4Address(): InetAddress? {
            val inter = NetworkInterface.getByName("wlan0")
            for (addr in inter.interfaceAddresses) {
                if (addr.address is Inet4Address) {
                    return addr.address
                }
            }
            throw Exception()
        }

        fun getIPv6Address(): InetAddress? {
            val inter = NetworkInterface.getByName("wlan0")
            for (addr in inter.interfaceAddresses) {
                if (addr.address is Inet6Address && !addr.address.isLinkLocalAddress) {
                    return addr.address
                }
            }
            throw Exception()
        }

        private fun encodeLabel(name: String): ByteArray {
            val labels = name.split(".")
            val buffer =
                ByteBuffer.allocate(labels.sumOf { it.length + 1 } + 1) // Length of labels + null byte
            for (label in labels) {
                buffer.put(label.length.toByte())
                buffer.put(label.toByteArray())
            }
            buffer.put(0x00)
            return buffer.array()
        }

        fun constructmDNSServiceAdvert(
            ipAddressV4: String?,
            serviceName: String,
            serviceType: String,
            port: Int,
            hostname: String,
            ttl: Int
        ): ByteArray {

            val headerSize = 12

            val ipV4Bytes = Inet4Address.getByName(ipAddressV4).address

            val serviceNameType = "$serviceName$serviceType.local"

            var newServiceType = "$serviceType.local"

            //Remove starting . if its present
            newServiceType =
                if (newServiceType.startsWith('.')) newServiceType.substring(1) else newServiceType

            val encodedServiceType = encodeLabel(newServiceType)
            val encodedServiceNameType = encodeLabel(serviceNameType)

            val hostNameParts = hostname.split(".")
            val encodedHostname = encodeLabel(hostname)

            val rDataSRVLength =
                6 + encodedHostname.size //the 6 are the priority, weight and port. 2 each
            val SRVSize =
                encodedServiceNameType.size + 10 + rDataSRVLength // 10 = 2 (type) + 2 (class) + 4 (TTL) + 2 (RDLENGTH)

            val ASize =
                encodedHostname.size + 10 + ipV4Bytes.size

            val PTRSize =
                encodedServiceType.size + 10 + encodedServiceNameType.size

            val textBytes = "Hacked".toByteArray()
            val rdata = ByteBuffer.allocate(textBytes.size + 1)
            rdata.put(textBytes.size.toByte())
            rdata.put(textBytes)
            val rdataBytes = rdata.array()

            val TXTSize =
                encodedServiceNameType.size + 10 + rdataBytes.size

            val bufferSize = headerSize + PTRSize + ASize + SRVSize + TXTSize
            val buffer = ByteBuffer.allocate(bufferSize)

            addDNSHeader(buffer, 4)
            // Question section (empty)

            // Answer section

            //PTR record

            addDNSAnswer(
                buffer,
                12.toShort(),
                encodedServiceType,
                ttl,
                (0x8001 and 0xFFFF).toShort(),
                encodedServiceNameType
            )

            //SRV Record
            val rDataSRV = ByteBuffer.allocate(rDataSRVLength)
            rDataSRV.putShort(0x0000) // Priority , Lowest possible
            rDataSRV.putShort(100.toShort()) //weight, Highest possible
            rDataSRV.putShort(port.toShort()) //Port number
            for (part in hostNameParts) {
                rDataSRV.put(part.length.toByte())
                rDataSRV.put(part.toByteArray())
            }
            rDataSRV.put(0x00)

            addDNSAnswer(
                buffer,
                33.toShort(),
                encodedServiceNameType,
                ttl,
                (0x8001 and 0xFFFF).toShort(),
                rDataSRV.array()
            )

            //TXT Record
            addDNSAnswer(buffer, 16.toShort(), encodedServiceNameType, ttl, 1.toShort(), rdataBytes)

//
            //A record
            addDNSAnswer(
                buffer,
                1.toShort(),
                encodedHostname,
                ttl,
                (0x8001 and 0xFFFF).toShort(),
                ipV4Bytes
            )

            return buffer.array()
        }

        fun constructmDNSResponse(
            ipAddressV4: String?,
            ipAddressV6: String?,
            hostname: String,
            ttl: Int
        ): ByteArray {
            val ipV4Bytes = Inet4Address.getByName(ipAddressV4).address
            val ipV6Bytes = Inet6Address.getByName(ipAddressV6).address


            // DNS Header is 12 bytes long
            val headerSize = 12

            // Encode domain name in DNS format
            val encodedHostname = encodeLabel(hostname)

            // Resource record sizes
            val rDataLengthV4 = ipV4Bytes.size
            val rrSizeV4 =
                encodedHostname.size + 10 + rDataLengthV4 // 10 = 2 (type) + 2 (class) + 4 (TTL) + 2 (RDLENGTH)

            val rDataLengthV6 = ipV6Bytes.size
            val rrSizeV6 =
                encodedHostname.size + 10 + rDataLengthV6 // 10 = 2 (type) + 2 (class) + 4 (TTL) + 2 (RDLENGTH)

            // Total buffer size
            val bufferSize = headerSize + rrSizeV4 + rrSizeV6
            val buffer = ByteBuffer.allocate(bufferSize)

            addDNSHeader(buffer, 2)
            // Question section (empty)

            // Answer section V4
            addDNSAnswer(
                buffer,
                0x0001.toShort(),
                encodedHostname,
                ttl,
                (0x8001 and 0xFFFF).toShort(),
                ipV4Bytes
            )

            // Answer section V6
            addDNSAnswer(
                buffer,
                0x001C.toShort(),
                encodedHostname,
                ttl,
                (0x8001 and 0xFFFF).toShort(),
                ipV6Bytes
            )


            return buffer.array()
        }

        private fun addDNSHeader(buffer: ByteBuffer, answerCount: Int) {
            // DNS Header
            buffer.putShort(0) // ID (2 bytes)
            buffer.put(0b10000100.toByte()) // QR (1 bit), Opcode (4 bits), AA (1 bit), TC (1 bit), RD (1 bit)
            buffer.put(0b00000000.toByte()) // RA (1 bit), Z (3 bits), RCODE (4 bits)
            buffer.putShort(0) // QDCOUNT (2 bytes)
            buffer.putShort(answerCount.toShort()) // ANCOUNT (2 bytes)
            buffer.putShort(0) // NSCOUNT (2 bytes)
            buffer.putShort(0) // ARCOUNT (2 bytes)
        }

        private fun addDNSAnswer(
            buffer: ByteBuffer,
            type: Short,
            nameBytes: ByteArray,
            ttl: Int,
            rclass: Short,
            rDataBytes: ByteArray
        ) {
            // Name
            buffer.put(nameBytes)

            // Type (A  or AAAA record)
            buffer.putShort(type)

            // Class (IN, with cache flush)
            buffer.putShort(rclass)

            // TTL (4 bytes)
            buffer.putInt(ttl)

            // RDLENGTH (2 bytes)
            buffer.putShort(rDataBytes.size.toShort())

            // RDATA
            buffer.put(rDataBytes)
        }
    }
}