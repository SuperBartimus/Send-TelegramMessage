
function Send-TelegramMessage {
    <#
.SYNOPSIS
Send a message to a Telegram chat.

.DESCRIPTION


.PARAMETER Message
The message to send.

.PARAMETER ParseMode
The parse mode to use. MarkdownV2 is the default.

.PARAMETER ImagePath
The path to the image to send.


.EXAMPLE
Send a plain text message.
    Send-TelegramMessage -Message 'Hello, world!'

.EXAMPLE
Send a message using Markdown Formatting.
    $Msg = "*Server Down!* `SRV-01` is offline. Check it [here](https://your.monitoring.link) 🔥"
    Send-TelegramMessage -Message $Msg -ParseMode 'MarkdownV2'

.EXAMPLE
Send a message with an image in Markdown.  Default parse mode is MarkdownV2
    $Msg = "*Server Down!* `SRV-01` is offline. Check it [here](https://your.monitoring.link) 🔥"
    Send-TelegramMessage -Message $Msg -ImagePath 'C:\image.png'

.EXAMPLE
Send a message using HTML formatting.
    $Msg = "<b>🔥 Alert!</b> <a href='https://your.monitoring.link'>Check Server</a>"
    Send-TelegramMessage -Message $Msg -ParseMode 'HTML'

.EXAMPLE
Send a message with an image in HTML.
    $Msg = "<b>🔥 Alert!</b> <a href='https://your.monitoring.link'>Check Server</a>"
    Send-TelegramMessage -Message $Msg -ParseMode 'HTML' -ImagePath 'C:\image.png'

.NOTES
Formatting Notes (MarkdownV2) https://core.telegram.org/bots/api#markdownv2-style
The following HTML/Markdown aliases for message entities can be used:

messageEntityBold => <b>bold</b>, <strong>bold</strong>, **bold**
messageEntityItalic => <i>italic</i>, <em>italic</em>, `_italic`_
messageEntityCode » => <code>code</code>, `code`
messageEntityStrike => <s>strike</s>, <strike>strike</strike>, <del>strike</del>, ~~strike~~
messageEntityUnderline => <u>underline</u>, `_`_underline`_`_
messageEntityPre » => <pre language="c++">code</pre>,
messageEntitySpoiler => <span class="tg-spoiler">spoiler</span>, ||spoiler||
messageEntityMonospace =>
messageEntityQuoted => ‘Quote’
messageEntityMention => @username, @channel, @chat, @all
messageEntityHashtag => #hashtag, #hashtag2
messageEntityBotCommand => /command, /command2
eg: *bold _italic bold ~italic bold strikethrough ||italic bold strikethrough spoiler||~ __underline italic bold___ bold*

Use [link text](http://link.url) for hyperlinks
Escape characters like _, *, [, ], (, ), etc., with \ if needed (Script will do this for you.)
Example: Check out \[this\](http://link.url)

.NOTES
Author: Bart S.
CreateDate: 2025-04-14

.REVISION HISTORY
2025-04-14 - BSS - Initial release

#>


    [CmdletBinding()]
    param (
        [string]$BotName = 'PwSh_bot', # specify a bot name or default to PwSh_bot
        [Parameter(Mandatory)]
        [string]$Message, # The message to send
        [string]$ParseMode, # $ParseMode must be either 'MarkdownV2' or 'HTML'
        [string]$ImagePath  # Optional: send an image with the message
    )

    # Determine token based on bot name
    switch ($BotName) {
        'YTdl_bot' { $Token = '81.......0:AAH.............................IBg' }
        'Work_bot' { $Token = '76.......4:AAG.............................t0g' }
           default { $Token = '80.......3:AAH.............................0sQ' }
    }

    $ChatID = '7992955237'

    function Convert-ToTelegramHtml {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory, Position = 0)]
            [string]$Message
        )

        Write-Verbose '[nl-debug] counts before fixes'
        $counts = [pscustomobject]@{
            DoubleSlashRN = ([regex]::Matches($Message, '\\\\r\\\\n')).Count  # \\r\\n
            DoubleSlashN  = ([regex]::Matches($Message, '\\\\n')).Count       # \\n
            SingleSlashRN = ([regex]::Matches($Message, '\\r\\n')).Count      # \r\n
            SingleSlashN  = ([regex]::Matches($Message, '\\n')).Count         # \n
            RealCRLF      = ([regex]::Matches($Message, "`r`n")).Count        # actual CRLF
            RealLF        = ([regex]::Matches($Message, "`n")).Count          # actual LF
            HtmlNLDec     = ([regex]::Matches($Message, '&#10;|&#x0A;')).Count
        }
        $counts | Format-List | Out-String | Write-Verbose

        # Show a small window around the first literal \n
        $hit = [regex]::Match($Message, '\\\\r?\\\\n|\\r?\\n')
        if ($hit.Success) {
            $start = [Math]::Max(0, $hit.Index - 20)
            $len = [Math]::Min(60, $Message.Length - $start)
            Write-Verbose ('[nl-debug] sample: ...' + $Message.Substring($start, $len) + '...')
        }

        # === Canonical newline fixes (order matters) ===
        # 1) Turn double-escaped \\r\\n first, then \\n, into REAL LF
        $Message = $Message -replace '\\\\r\\\\n', "`n"
        $Message = $Message -replace '\\\\n', "`n"

        # 2) If caller used single-escaped \n, unescape them to REAL LF
        $Message = [System.Text.RegularExpressions.Regex]::Unescape($Message)  # \n -> LF

        # 3) HTML/JSON entities -> REAL LF
        $Message = $Message -replace '&#10;|&#x0A;', "`n"

        # 4) Normalize any real CRLF to LF, and trim spaces around LFs
        $Message = $Message -replace "`r?`n", "`n"
        $Message = $Message -replace '[ \t]*`n[ \t]*', "`n"

        Write-Verbose '[nl-debug] counts after fixes'
        $after = [pscustomobject]@{
            DoubleSlashRN = ([regex]::Matches($Message, '\\\\r\\\\n')).Count
            DoubleSlashN  = ([regex]::Matches($Message, '\\\\n')).Count
            SingleSlashRN = ([regex]::Matches($Message, '\\r\\n')).Count
            SingleSlashN  = ([regex]::Matches($Message, '\\n')).Count
            RealCRLF      = ([regex]::Matches($Message, "`r`n")).Count
            RealLF        = ([regex]::Matches($Message, "`n")).Count
        }
        $after | Format-List | Out-String | Write-Verbose

        Write-Verbose '[br] convert <br> to newlines'
        $Message = $Message -replace '(?i)<br\s*/?>', "`n"

        Write-Verbose '[block] convert common block tags to newlines'
        $Message = $Message -replace '(?i)</?(p|div|section|article|header|footer|aside|nav|center|address|figure|figcaption)>', "`n"

        Write-Verbose '[h1-6] map headings to <b>text</b> + newline'
        $Message = [regex]::Replace($Message, '(?is)<h[1-6][^>]*>(.*?)</h[1-6]>', {
                param($m)
                $txt = [regex]::Replace($m.Groups[1].Value, '\s+', ' ').Trim()
                "<b>$txt</b>`n"
            })

        Write-Verbose '[hr] replace hr with rule text'
        $Message = $Message -replace '(?i)</?hr[^>]*>', "`n———`n"

        Write-Verbose '[lists] collapse <ol>/<ul> to newlines and convert <li> to bullets'
        $Message = $Message -replace '(?i)</?(ol|ul)[^>]*>', "`n"
        $Message = $Message -replace '(?is)<li[^>]*>\s*', '  • '
        $Message = $Message -replace '(?i)</li>', "`n"

        Write-Verbose '[tables] extract rows/cells and wrap in <pre>'
        $Message = [regex]::Replace($Message, '(?is)<table[^>]*>(.*?)</table>', {
                param($m)
                $table = $m.Groups[1].Value
                # Heal missing </tr>
                $opens = ([regex]::Matches($table, '(?i)<tr[ >]')).Count
                $closes = ([regex]::Matches($table, '(?i)</tr>')).Count
                if ($opens -gt $closes) { $table += ('</tr>' * ($opens - $closes)) }

                $rows = [System.Collections.Generic.List[string]]::new()
                foreach ($tr in [regex]::Matches($table, '(?is)<tr[^>]*>(.*?)</tr>')) {
                    $cells = foreach ($td in [regex]::Matches($tr.Groups[1].Value, '(?is)<(td|th)[^>]*>(.*?)</\1>')) {
                        ([regex]::Replace($td.Groups[2].Value, '\s+', ' ')).Trim()
                    }
                    if ($cells.Count) { $rows.Add(($cells -join ' | ')) }
                }
                $body = ($rows | Where-Object { $_ -and $_.Trim() }) -join "`n"
                if ([string]::IsNullOrWhiteSpace($body)) { return '' }
                "<pre>$body</pre>"
            })

        Write-Verbose '[trash] drop script/style/meta/etc'
        $Message = $Message -replace '(?is)<(script|style|meta|link|title|head|html|body|!doctype)[^>]*>.*?</\1>', ''
        $Message = $Message -replace '(?is)</?(script|style|meta|link|title|head|html|body|!doctype)[^>]*>', ''

        # --- keep links BEFORE attribute stripping ---
        Write-Verbose '[links] normalize <a> and <tg-emoji> to minimal attrs'
        $patternA = @'
(?is)<a\s+[^>]*href\s*=\s*(['"])(.*?)\1[^>]*>
'@
        $replaceA = @'
<a href="$2">
'@
        $Message = [regex]::Replace($Message, $patternA, $replaceA)

        $patternE = @'
(?is)<tg-emoji\s+[^>]*emoji-id\s*=\s*(['"])(.*?)\1[^>]*>
'@
        $replaceE = @'
<tg-emoji emoji-id="$2">
'@
        $Message = [regex]::Replace($Message, $patternE, $replaceE)

        # Drop any bare <a> without href (unwrap its content)
        $Message = $Message -replace '(?is)<a>(.*?)</a>', '$1'

        Write-Verbose '[code/pre] normalize multiline <code> to <pre>'
        $Message = [regex]::Replace($Message, '(?is)<code>([^<]*?\n[^<]*?)</code>', '<pre>$1</pre>')

        Write-Verbose '[attrs] strip attributes from allowed tags'
        $Message = [regex]::Replace($Message, '(?is)<(a|b|strong|i|em|u|ins|s|strike|del|code|pre|blockquote|tg-spoiler|tg-emoji)(\s+[^>]*)?>', '<$1>')

        Write-Verbose '[unwrap] remove all other tags (leave content)'
        $Message = [regex]::Replace($Message, '(?is)</?(?!a|b|strong|i|em|u|ins|s|strike|del|code|pre|blockquote|tg-spoiler|tg-emoji)\w+[^>]*>', '')

        Write-Verbose '[guard] escape any non-allowed tag openings (e.g., <"  < >)'
        $Message = [regex]::Replace($Message, '(?i)<(?!/?(?:a|b|strong|i|em|u|ins|s|strike|del|code|pre|blockquote|tg-spoiler|tg-emoji)\b)', '&lt;')

        Write-Verbose '[entities] fix &nbsp; and stray &'
        $Message = $Message -replace '&nbsp;', ' '
        $Message = $Message -replace '(?<!&)&(?!lt;|gt;|amp;|quot;|#\d+;|#x[0-9a-fA-F]+;)', '&amp;'
        $Message = $Message -replace '&amp;(lt|gt|amp|quot);', '&$1;'

        Write-Verbose '[balance] ensure <pre> pairs are balanced'
        $preOpen = ([regex]::Matches($Message, '(?i)<pre>')).Count
        $preClose = ([regex]::Matches($Message, '(?i)</pre>')).Count
        if ($preOpen -gt $preClose) {
            Write-Verbose "adding $($preOpen-$preClose) missing </pre>"
            $Message += ('</pre>' * ($preOpen - $preClose))
        }
        elseif ($preClose -gt $preOpen) {
            Write-Verbose "removing $($preClose-$preOpen) trailing </pre>"
            $Message = $Message -replace "(?i)(</pre>){$($preClose-$preOpen)}$", ''
        }

        Write-Verbose '[collapse] compress blank lines'
        $Message = $Message -replace '([ \t]*`n){3,}', "`n`n"

        Write-Verbose '[done]'
        return $Message.Trim()
    }


    # Retrieve dynamic info about the system and user
    $ComputerName = $env:COMPUTERNAME
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $IsBot = $true  # Since you're using a bot, we can hard-code this
    $PowerShellVersion = $PSVersionTable.PSVersion.Major.ToString() + '.' + $PSVersionTable.PSVersion.Minor.ToString()

# Works anywhere in the script, even inside functions
$scriptPath = $PSCommandPath
$scriptModifiedDate = (Get-Item -LiteralPath $scriptPath).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')

Write-Host "Script Path: $scriptPath" -ForegroundColor DarkYellow
Write-Host "Script Modified Date: $scriptModifiedDate" -ForegroundColor DarkYellow



    # Build the sender identification message
    if (-not $ParseMode) {
        # Assume ParseMode is Text
        # $ParseMode = 'Text' # not a valid descriptor.  For plain text, you don't specify a parse mode
        $SenderInfo = "Device: $ComputerName`nUser: $CurrentUser`nBot: $IsBot`nParseMode: $ParseMode`nPSVer: $PowerShellVersion`nScriptModDate: $scriptModifiedDate"

    }


    if ($ParseMode -eq 'MarkdownV2') {
        # Escape all special characters that need to be escaped for MarkdownV2
        $pattern = '([\/>#+\-=|{}.\!\\])'

        $Message = $Message -replace $pattern, '\$1'

        $ComputerName = "\$ComputerName" -replace $pattern, '\$1'
        $CurrentUser = $CurrentUser -replace $pattern, '\$1'

        $SenderInfo = "  Device:    ` $ComputerName ` `n  User:       ` $CurrentUser ` "
        $SenderInfo = $SenderInfo -replace $pattern, '\$1'
        $footer = "     Bot: `_`_$IsBot`_`_     ParseMode: `_$ParseMode`_   PSVer: `_$PowerShellVersion`_   ScriptModDate: `_$scriptModifiedDate`_"

    }

    if ($ParseMode -eq 'HTML') {
        $SenderInfo = @"
  Device:   <b>\\$ComputerName</b>
  User:      <b>$CurrentUser</b>
"@
        $footer = "    Bot: <i>$IsBot</i>     ParseMode: <i>$ParseMode</i>   PSVer: <i>$PowerShellVersion</i>   ScriptModDate: <i>$scriptModifiedDate</i>"
    }

    try {
        # Fix HTML $message to be Telegram friendly
        $Message = Convert-ToTelegramHtml -Message $Message -Verbose


        # Combine the sender info with the original message
        $MessageWithSenderInfo = "Sender:`n$SenderInfo`nMessage:`n$Message`n`n$footer"

        if ($ImagePath -and (Test-Path $ImagePath)) {
            # Create an HttpClient instance.
            $httpClient = [System.Net.Http.HttpClient]::new()

            # Create the multipart form data content.
            $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()

            # Add the chat_id, caption, and parse_mode fields.
            $multipartContent.Add([System.Net.Http.StringContent]::new($ChatID), 'chat_id')
            $multipartContent.Add([System.Net.Http.StringContent]::new($MessageWithSenderInfo), 'caption')
            $multipartContent.Add([System.Net.Http.StringContent]::new($ParseMode), 'parse_mode')

            # Read the image file as bytes and create a ByteArrayContent.
            $fileBytes = [System.IO.File]::ReadAllBytes($ImagePath)
            $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)

            # Set the Content-Type header (adjust the MIME type if your image isn't PNG)
            # Determine MIME type based on file extension
            $ext = [System.IO.Path]::GetExtension($ImagePath).ToLowerInvariant()
            switch ($ext) {
                '.png' { $mimeType = 'image/png' }
                '.jpg' { $mimeType = 'image/jpeg' }
                '.jpeg' { $mimeType = 'image/jpeg' }
                '.gif' { $mimeType = 'image/gif' }
                '.webp' { $mimeType = 'image/webp' }
                default { $mimeType = 'application/octet-stream' }
            }
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($mimeType)


            $fileName = Split-Path $ImagePath -Leaf

            # Add the image file to the multipart content; the parameter must be named "photo"
            $multipartContent.Add($fileContent, 'photo', $fileName)

            # Send the POST request to Telegram.
            $Uri = "https://api.telegram.org/bot$Token/sendPhoto"
            $response = $httpClient.PostAsync($Uri, $multipartContent).Result
            $result = $response.Content.ReadAsStringAsync().Result

            Write-Host $result
        }

        else {
            # Send plain text message
            $Uri = "https://api.telegram.org/bot$Token/sendMessage"

            $Body = @{
                chat_id    = $ChatID
                text       = $MessageWithSenderInfo
                parse_mode = $ParseMode
            }
            Write-Host $MessageWithSenderInfo -fore cyan
            $Body | Format-Table -AutoSize
            Invoke-RestMethod -Uri $Uri -Method Post -Body $Body | Format-Table
        }
    }
    catch {
        Write-Warning "Failed to send Telegram message: $_"
    }

}

<#
& {
$msg = "*Server Down!* `SRV-01` is offline. Check it [here](https://your.monitoring.link) 🔥"
. .\Send-TelegramMessage.ps1 ; send-telegrammessage -ParseMode MarkdownV2 -message $msg
. .\Send-TelegramMessage.ps1 ; Send-TelegramMessage -ParseMode MarkdownV2 -Message $Msg -ImagePath "C:\Users\StraussB\Downloads\OnMicrosoft.png"

$Msg = "<b>🔥 Alert!</b>`n<b>\\SRV-01</b> is offline.`n<a href='https://your.monitoring.link'>Check Server</a>"
. .\Send-TelegramMessage.ps1 ; Send-TelegramMessage -ParseMode HTML -Message $Msg
. .\Send-TelegramMessage.ps1 ; Send-TelegramMessage -ParseMode HTML -Message $Msg -ImagePath "C:\Users\StraussB\Downloads\OnMicrosoft.png"

$Msg = "🔥 Alert!`nhttps://your.monitoring.link"
Send-TelegramMessage -Message $Msg
Send-TelegramMessage -Message $Msg -ImagePath "C:\Users\StraussB\Downloads\OnMicrosoft.png"
}

#>
