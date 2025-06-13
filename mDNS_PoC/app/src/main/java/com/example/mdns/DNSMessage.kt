package com.example.mdns

class DNSMessage(private val data: ByteArray) {

    // Extract the query name from the DNS packet
    fun isQueryFor(expectedName: String): Boolean {
        // DNS header is 12 bytes, question section starts after that
        val name = getQueryName()

        // Compare with the expected name
        return name.contains(expectedName)
    }

    fun getQueryName(): String {
        // DNS header is 12 bytes, question section starts after that
        val offset = 12
        val queryName = StringBuilder()
        var pos = offset
        while (true) {
            val length = data[pos].toInt()
            if (length == 0) {
                break
            }
            pos++
            queryName.append(String(data, pos, length))
            pos += length
            queryName.append(".")
        }
        val name = queryName.toString().dropLast(1)
        // Compare with the expected name
        return name
    }
}