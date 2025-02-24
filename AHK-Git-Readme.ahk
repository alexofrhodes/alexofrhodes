#Requires AutoHotkey v2
#Include "lib\jsongo.v2.ahk"

GlobalVariables:
{
    selectedUserName := ""
    selectedRepoName := ""
    selectedRepoURL := ""
    selectedRepoFolder := ""
    selectedConfigPath := ""

    username := ""
    reponame := ""
    repourl := ""
}


Settings:
{
    scriptFolder := A_ScriptDir
    scriptFolderAsUsername := RegExReplace(scriptFolder, ".*\\([^\\]*)$", "$1")

    gitUsernames := [scriptFolderAsUsername]    ; <----

    scriptParentFolder := RegExReplace(scriptFolder, "\\[^\\]*$")
    parentFolders := [scriptParentFolder]       ; <----
    recursive := false                          ; <----

    Headers := ["VBA","AHK"]                    ; <----
    CreateOtherCategory := true                 ; <----
    readmePath := A_ScriptDir "\README.md"      ; <----

    ; 1 = getReposFromFolders 
    ; 2 = GetReposFromGitHub
    chosenMethod := 2                           ; <----
    outputToCSV := false                        ; <----

    prependText := 
    (LTrim
    "Hi there 👋 I'm Alex.
    
    - [Github](https://github.com/alexofrhodes/)
    - [Email](mailto:anastasioualex@gmail.com?subject=Hello&body=Hi!%20I%20would%20like%20to%20talk%20about%20...)
    - [BuyMeACoffee](https://www.buymeacoffee.com/AlexOfRhodes)
    - [WebSite](https://alexofrhodes.github.io/) 
    - [YouTube](https://www.youtube.com/@alexofrhodes)
    - [LinkedIn](www.linkedin.com/in/alexofrhodes/)
    - [InstaGram](https://www.instagram.com/alexofrhodes/)
    
    This README was automatically generated with an AutoHotkey tool I wrote.  
    You can find it at [GitHub](https://github.com/alexofrhodes/alexofrhodes)  
    "
    )
    

    AppendText := ""
}

Main:
{
    if (chosenMethod = 1)
        repoList := getReposFromFolders(parentFolders, recursive)
    if (chosenMethod = 2)
        repoList := GetReposFromGitHub(gitUsernames)
    if outputToCSV
        CreateCSV() 

    CreateReadme(headers, CreateOtherCategory)
}


; `````````````````
; ``` FUNCTIONS ```
; `````````````````

; MAIN ------------------------------------------------------------------

/**
 * 
 * @param {Array} RepoBeginsAsHeader eg. ["AHK","VBA"] lists repos beginning with these under respective headers
 * @param {Integer} createOtherHeader 
 */
CreateReadme(RepoBeginsAsHeader, createOtherHeader := false) {
    global
    output := ""
    ; MsgBox "Formatting repo list with headers..."  ; Notify when formatting begins

    ; Create a header group for each match string
    for each, matchString in RepoBeginsAsHeader {
        sectionOutput := ""
        for each, repo in repoList {
            if !repo.repoURL
                continue
            ; if InStr(repo.repoName, matchString) 
            if SubStr(repo.repoName, 1, StrLen(matchString)) = matchString {
                ; MsgBox "Matched repo: " repo.repoName " for header: " matchString
                sectionOutput .= "[![Readme Card](https://github-readme-stats.vercel.app/api/pin/?username=" repo.username "&repo=" repo.repoName ")](" repo.repoURL ")" "`n"
            }
        }
        if sectionOutput != "" {
            output .= "`n## " matchString "`n" sectionOutput
        }
    }

    ; If 'Other' header is allowed, include repositories that don't match any string
    if createOtherHeader {
        otherOutput := ""
        for each, repo in repoList {
            if !repo.repoURL
                continue
            matched := false
            for each, matchString in RepoBeginsAsHeader {
                ; if InStr(repo.repoName, matchString) 
                if SubStr(repo.repoName, 1, StrLen(matchString)) = matchString {
                    matched := true
                    break
                }
            }
            if !matched {
                ; MsgBox "Repo doesn't match any header: " repo.repoName
                otherOutput .= "[![Readme Card](https://github-readme-stats.vercel.app/api/pin/?username=" repo.username "&repo=" repo.repoName ")](" repo.repoURL ")" "`n"
            }
        }
        if otherOutput != "" {
            output .= "`n## Unsorted`n" otherOutput
        }
    }

    ; Append output to README.md
    
    try FileDelete(readmePath)


    output := prependText . output . appendText
    try {
        FileAppend(output, readmePath)
        MsgBox "Formatted output appended to README.md"
    } catch {
        MsgBox "Error appending to README.md: " . A_LastError
    }
}


; LOCAL ---------------------------------------------------------------

/**
 * 
 * @param {Array} foldersToScan 
 * @param {Integer} recursive 
 * @returns {Array} repoList { userName, repoName, repoURL, repoFolder }
 */
GetReposFromFolders(foldersToScan, recursive := false) {
    repoList := []
    loopMode := recursive ? "R" : ""

    for each, folderToScan in foldersToScan {
        Loop Files, folderToScan "\*", "D" loopMode {
            gitConfigPath := A_LoopFileFullPath "\.git\config"
            if FileExist(gitConfigPath) {
                GetInfo(gitConfigPath)
                ; if (username && repoName && repoURL) {
                    repoList.Push({username: username, repoName: repoName, repoURL: repoURL, repoFolder: A_LoopFileFullPath})
                ; }
            }
        }
    }
    return repoList
}

/**
 * updates global variables userName, repoName, repoURL
 * @param gitConfigPath 
 */
GetInfo(gitConfigPath){
    global
    contents := ""
    username := ""
    repoName := ""
    repoURL :=  ""
    contents := FileRead(gitConfigPath)
    if RegExMatch(contents, "url\s*=\s*(https?://github\.com/([^/]+)/|git@github\.com:([^/]+)/?)", &match)         
        username := match[2] ? match[2] : match[3]
    if RegExMatch(contents, "url\s*=\s*(https?://github\.com/[^/]+/([^/]+)\.git|git@github\.com:[^/]+/([^/]+)\.git)", &match) 
        repoName := match[2] ? match[2] : match[3]
    if RegExMatch(contents, "url\s*=\s*(git@github\.com:|https://github\.com/)([^/]+)/([^/]+)\.git", &match) 
        repoURL :=  "https://github.com/" match[2] "/" match[3]    
}


; REMOTE --------------------------------------------------------------

/**
 * 
 * @param {Array} usernames 
 * @returns {Array} repoList { userName, repoName, repoURL, repoFolder := "" }
 */
GetReposFromGitHub(usernames) {
    global
    repoList := []

    if !HasInternet()
        return

    for each, username in usernames {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        Address := "https://api.github.com/users/" username "/repos"
        whr.Open("GET", Address, true)
        whr.Send()
        whr.WaitForResponse()

        status := whr.status
        if (status != 200) {
            MsgBox "HttpRequest error for " username ", status: " status
            continue
        }

        JsonString := whr.ResponseText
        JsonObject := JSONgo.Parse(JsonString)  ; Parse the JSON response

        if !IsObject(JsonObject) {
            MsgBox "Parsing JSON for " username " failed."
            continue
        }

        ; Extract the repository details and store in repoList
        for index, repo in JsonObject {
            repoName := repo["name"]
            repoURL := repo["html_url"]
            repoList.Push({username: username, repoName: repoName, repoURL: repoURL, repoFolder: ""})
        }
    }

    return repoList
}


; OPTIONAL --------------------------------------------------------------

/**
 * (optional) save repo info to csv and show on gui
 */
CreateCSV(*)
{
    global
    csvRows := ["Username,Repo Name,Remote URL,Folder Path"]  ; CSV header

    ; Create a myGui with ListView
    myGui := Gui()
    myGui.SetFont("s10")
    
    ; Add buttons for operations
    myGui.Add("Button", , "Open Folder").OnEvent("Click", OpenFolder)
    myGui.Add("Button", , "Open Config").OnEvent("Click", OpenConfig)
    myGui.Add("Button", , "Open URL").OnEvent("Click", OpenURL)
    
    LV := myGui.Add("ListView", "w600 r20", ["Username","Repo","URL","Folder"])
    ; Add repository details to ListView and CSV rows
    for each, repo in repoList {
        row := [repo.username, repo.repoName, repo.repoURL, repo.repoFolder]
        LV.Add("", repo.username, repo.repoName, repo.repoURL, repo.repoFolder)
        csvRows.Push(Join(row, ","))  ; Prepare CSV row
    }
    lv.ModifyCol(1)
    lv.ModifyCol(2)
    lv.ModifyCol(3,50)
    lv.ModifyCol(4,50)
    
    ; Display the myGui
    myGui.Show()
    
    ; Save all CSV rows at once
    outputFile := A_ScriptDir "\repositories.csv"
    try FileDelete(outputFile)  ; Remove existing file
    FileAppend(Join(csvRows, "n"), outputFile)  ; Write CSV rows
    
    ; On selecting a row, update the global variables
    LV.OnEvent("ItemSelect", OnItemClick)
}

OnItemClick(LV, *) {
    global
    selectedRow := LV.GetNext(0)
    if selectedRow {
        selectedUsername := LV.GetText(selectedRow, 1)
        selectedRepoName := LV.GetText(selectedRow, 2)
        selectedRepoURL := LV.GetText(selectedRow, 3)
        selectedRepoFolder := LV.GetText(selectedRow, 4)
        selectedConfigPath := selectedRepoFolder "\.git\config"
    }
}

OpenFolder(*) {
    if selectedRepoFolder {
        Run(selectedRepoFolder)
    } else {
        MsgBox "No repository folder selected."
    }
}

OpenConfig(*) {
    if FileExist(selectedConfigPath) {
        Run(selectedConfigPath)
    } else {
        MsgBox "No .git/config file found."
    }
}

OpenURL(*) {
    if selectedRepoURL {
        Run(selectedRepoURL)
    } else {
        MsgBox "No repository URL found."
    }
}


; HELPERS ---------------------------------------------------------------

/**
 * Function to join strings with a specified delimiter
 * @param {Array} s 
 * @param {String} h concatenator
 * @param t 
 */
Join(s, h, t*) {
    for _, x in t
        h .= s . x
    return h
}

HasInternet() {
    return UrlDownloadToVar("http://www.google.com")
}

UrlDownloadToVar(URL){
    try {
        WebRequest := ComObject("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("GET", URL)
        WebRequest.Send()
        return WebRequest.ResponseText
    } catch {
        return ""
    }
}
