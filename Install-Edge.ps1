# A one-liner to install Edge (current) on IE-restricted systems

$client = New-Object System.Net.WebClient ; $client.DownloadFile("https://c2rsetup.officeapps.live.com/c2r/downloadEdge.aspx?platform=Default&source=EdgeStablePage&Channel=Stable&language=en&consent=1", 'C:\temp\edge.exe') ; Start-Sleep -Seconds 5 ;  & 'C:\temp\edge.exe'
