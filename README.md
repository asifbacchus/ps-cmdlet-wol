# PowerShell cmdlet: Send Magic Packet

PowerShell cmdlet (module/function) to send a *magic packet* based on provided MAC address(es). Comment-based help is
included in the source-code: `Get-Help Send-MagicPacket -Full`

## Contents

<!-- toc -->

- [Installation and verification](#installation-and-verification)
    * [Example: Auto-load for current user](#example-auto-load-for-current-user)
- [Overview](#overview)
- [Broadcast considerations](#broadcast-considerations)
- [Pipeline](#pipeline)
- [Module or Function](#module-or-function)
- [Feedback](#feedback)

<!-- tocstop -->

## Installation and verification

Downloads are available via [my git server](https://git.asifbacchus.dev/asif/ps-cmdlet-wol/releases/latest)
and [GitHub](https://github.com/asifbacchus/ps-cmdlet-wol/releases/latest). You may verify the cmdlet's integrity
using [CodeNotary](https://codenotary.io) via `vcn authenticate` or by dropping the downloaded script and/or manifest
onto their verification webpage at [https://verify.codenotary.io](https://verify.codenotary.io). Please always try to
verify downloaded scripts and software regardless of the source!

If you are integrating this function with your own project or want to manually load the module as needed, then save the
module and manifest file wherever it is convenient for you. If you want to auto-load this function so it is available
automatically in any PowerShell session then you *must* extract it to a directory named **wol-magicPacket** somewhere
defined in your `PSModulePath` depending on your use-case. More information can be found directly from
Microsoft [here](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules?view=powershell-7.1#short-description)
.

### Example: Auto-load for current user

Here's a complete example assuming I want the module automatically available for all sessions running under my user
account:

```powershell
# download version 1.1
Invoke-WebRequest -Uri https://git.asifbacchus.dev/asif/ps-cmdlet-wol/archive/v1.1.zip -OutFile "$Env:DOWNLOADS\ps-cmdlet-wol.zip"

# Get PSModulePath
# You should see a user-level modules path in the form of either:
#  C:\Users\Username\Documents\WindowsPowerShell\Modules  -OR-
#  C:\Users\Username\Documents\PowerShell\Modules
$Env:PSModulePath

# change directory to the appropriate path from above
Set-Location "C:\Users\Username\Documents\WindowsPowerShell\Modules"

# extract files and rename directory
Expand-Archive -Path "$Env:DOWNLOADS\ps-cmdlet-wol.zip" -DestinationPath .\
Rename-Item -Path ps-cmdlet-wol -NewName wol-magicPacket

# confirm: you should see a directory named 'wol-magicPacket'
gci

# confirm: you should see the manifest and module within the wol-magicPacket folder
gci .\wol-magicPacket
```

Now, close and re-open PowerShell and the `Send-MagicPacket` function should be available:

```powershell
Get-Command Send-MagicPacket
```

## Overview

The function sends two (2) magic packets spaced one (1) second apart. One set of magic packets will be sent per MAC
address submitted either directly via the `MacAddress` parameter or via the pipeline (implicitly or explicitly). Usage
examples are provided via `Get-Help Send-MagicPacket -Examples`.

The only mandatory parameter is `MacAddress` which can be provided directly or via the pipeline either implicitly or
explicitly (parameter is in the first position). `MacAddress` is an *array of strings*. The actual hex values of the MAC
address can be separated with a colon (':') and/or a hyphen ('-'). For example, the following MAC addresses are all
valid even within the same command:

```powershell
Send-MagicPacket '1a:2b:3c:4d:5e:aa', 'a1-b2-c3-d4-e5-bb', '1a:2b-3c:4d-5e-cc'
```

By default, the magic packet will be sent on the global broadcast address for your current system (e.g. 255.255.255.255)
using UDP on the *echo* port (7). These options can be customized via parameters:

- `-BroadcastIP` | `IP` | `Address`: Broadcast address to use. By default, this is 255.255.255.255 but you really should
  use a subnet specific broadcast address instead (e.g. 192.168.1.255). See
  the [Broadcast considerations](#broadcast-considerations) section for more discussion.
- `Port`: Allows changing the UDP port over which the magic packet is sent. This is by default port 7 (echo). Port 9 (
  discard) is also quite common but any port can be used depending on your particular environment.

The magic packet is constructed as per standards: 6 byte header consisting of '255' (hex:FF) followed by the
hex-represented MAC addresses repeated 16 times.

## Broadcast considerations

Long ago in a galaxy far away... actually a few decades ago right here on Earth, the easiest way to send Wake-On-Lan (
WOL) packets was simply to use the global IP4 all-subnets broadcast address of 255.255.255.255. Because this generates a
lot of un-needed traffic, breaks subnet isolation and can be an attack vector, many routers and switches now block this
type of broadcast. Although this remains the default for most WOL applications (including this function), it is vastly
more reliable and preferred to use a subnet-specific broadcast address. For example, if you are concerned with computers
on your subnet of 192.168.1.0/24 then you would use the broadcast address of 192.168.1.255.

More recently, it has also become somewhat common to use the multicast all-hosts address of **224.0.0.1** when sending
WOL packets. If broadcast is not working in your environment, you may want to try this as a possible workaround.

Things become a little more complicated with IP6. There is no concept of 'broadcast' in IP6 and thus, you need to use
multicast. I have not extensively tested IP6 WOL since I tend to continue using IP4 for this purpose (all my networks
are dual-stack). I would assume the simplest place to start testing would be using the link-local all-nodes address
of **ff02::1**. I suspect this should work across most networks, but I have not tested it extensively and it would
depend greatly on switches, routers and even machine specific set-ups.

## Pipeline

This function is geared toward pipeline usage. The variable `MacAddress` is parameterized and used by the function for
an array of string objects representing individual MAC addresses. This is consistent with WMIC/CIMv2 output for most NIC
queries and allows this function to be easily called using piped output from such a query. To see this, try sending some
dummy magic packets to the localhost for all interfaces on the local machine:

```powershell
# get name, manufacturer and MAC address for connected interfaces and pipe to our function 
Get-CimInstance -Query "Select * From Win32_NetworkAdapter Where NetConnectionStatus=2" | Select-Object Name, Manufacturer, MacAddress | Send-MagicPacket -IP 127.0.0.1 -Verbose
```

You will notice I've selected stuff we don't need (Name, Manufacturer) to show that the function can parse and pick up
named the `MacAddress` of each object (network interface) and then send a magic packet to 127.0.0.1 on port 7 (echo).
This is not at all useful, but demonstrates pipeline usage quite nicely, I think. A simpler demonstration would be the
following:

```powershell
# send magic packets to two machines over IP4 localhost using port 9 (discard)
'1a:2b:3c:4d:5e:aa', 'a1:b2:c3:d4:e5:bb' | Send-MagicPacket -BroadcastIP 127.0.0.1 -Port 9
```

## Module or Function

This was intended to be used as a simple function that can be integrated into other scripts directly or, more
conveniently, loaded as a module and referenced as needed in a variety of use-cases.

If using as a function, simply place it within your script. If you want to load it as a module either `Load-Module`
within your script or do so at a PS prompt:

```powershell
# load module
Load-Module C:\path\to\module\wol-magicPacket.psm1

# call module anytime after loading within the same session
Send-MagicPacket ...
```

## Feedback

I coded this pretty quickly for a project I was working on in a small LAN deployment. I also use it routinely in
networks of various sizes and over VPN connections and also when I'm too lazy to move from my office to the living room
to turn on my media centre. I've polished it up and added comment-based help for the version in this repo, hence the
more recent creation date. I'm always interested in improvements since I don't code in PowerShell that often and I'm
sure this can be vastly improved. Please send any suggestions, bugs, etc. to me by filing an issue.

I hope you find this useful! As indicated by the license, you can use this code for whatever you want in any capacity.
If you do use it, a link to my blog at [https://mytechiethoughts.com](https://mytechiethoughts.com) would be greatly
appreciated!