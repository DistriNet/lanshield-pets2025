var exploitUpdates = ""


function updateExploitState(text) {
    console.log(text);
    exploitUpdates = exploitUpdates + text + "<br />";
    // Print in div
    const resultsDiv = document.getElementById("results");
    resultsDiv.innerHTML = exploitUpdates;
}



document.addEventListener('DOMContentLoaded', function() {
//    
    let startButton = document.getElementById('start-button');
    updateExploitState("Extension loaded");
    
    startButton.addEventListener('click', function() {
        updateExploitState("Starting exploit.");
        
        browser.runtime.sendMessage(
                                    {action: 'startExploit'},
                                    response => {
                                        if (response.success) {
                                            console.log(`Exploit successful ${response.log}`);
                                            updateExploitState(response.log)
                                        } else {
                                            console.error(`Error, exploit failed ${response.log}`);
                                            updateExploitState(response.log)
                                        }
                                    }
                                    )
    });
    
});
