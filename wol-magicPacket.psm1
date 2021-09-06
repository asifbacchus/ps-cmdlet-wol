<#
.SYNOPSIS
Broadcast one or more "magic packets" across a subnet to wake-up one or more target computers.

.DESCRIPTION
Sends two (2) "magic packets" spaced one (1) second apart per supplied MAC address as a broadcast over the subnet using a specified UDP port. MAC addresses can be supplied directly or via the pipeline either with or without explicitly specifying a parameter. The broadcast address and UDP port can be specified via parameters.

Note: You must specify the '-Verbose' parameter to see output for successfully sent packets.

.PARAMETER MacAddress
Array of MAC addresses for which to construct magic packets. The array should be provided in standard comma-separated string format ('1a:2a:3a:4a:5a:aa', '1b:2b:3b:4b:5b:bb', ...). You may use either a colon (:) or a hyphen (-) to delimit each hex value-pair in the MAC address. You may supply this array either directly or via the pipline.

.PARAMETER BroadcastIP
The address to which magic packets should be sent in order for them to be broadcast across the subnet. By default this is 255.255.255.255 however, many routers block such global broadcasts. Therefore, it is suggested to use the subnet-specific broadcast address (e.g. 192.168.1.255). You may also use IP6 multicast addresses (ff02::1 may work in your environment) if you prefer.

.PARAMETER Port
The UDP port that should be used when sending the broadcast. By default this is port 7 (echo). Port 9 (discard) is also a common port.

.INPUTS
String array or object containing a string array named "MacAddress".

.EXAMPLE
Send-MagicPacket 1a-2a-3a-4a-5a-aa
Wake-up a computer with MAC address '1a-2a-3a-4a-5a-aa' via global broadcast using default port (echo).

.EXAMPLE
Send-MagicPacket '1a-2a-3a-4a-5a-aa' 192.168.1.255 9
Wake-up a computer with MAC address '1a-2a-3a-4a-5a-aa' in subnet 192.168.1.0/24 using port 9 (discard).

.EXAMPLE
Send-MagicPacket -MacAddress '1a-2a-3a-4a-5a-aa', '1b-2b-3b-4b-5b-bb', '1c:2c:3c:4c:5c:cc' -Port 99 -BroadcastIP 10.0.1.255 -Verbose
Wake-up 3 computers in the specified subnet using non-standard port. Parameters are explicitly defined. Show confirmation messages for each MAC address.

.EXAMPLE
'1a-2a-3a-4a-5a-aa', '1b-2b-3b-4b-5b-bb' | Send-MagicPacket -IP 172.16.20.255 -Verbose
Use pipeline to provide MAC addresses, provide broadcast address directly. Show result.

.NOTES
There is no output generated for successfully sent packets. This is done to keep the pipeline clear. To see success confirmation messages, run this function with the '-Verbose' parameter.
#>
function Send-MagicPacket
{
    [CmdletBinding()]
    param
    (
    # Array of MAC addresses for which to construct magic packets
        [Parameter(
                Mandatory,
                ValueFromPipeline,
                ValueFromPipelineByPropertyName,
                HelpMessage = "Please provide one or more MAC addresses. You may use a colon (:) or a hypen (-) to separate hex values."
        )]
        [String[]]
        $MacAddress,

    # Broadcast IP address (default: all subnets --> 255.255.255.255)
        [Alias("IP", "Address")]
        [Parameter()]
        [IPAddress]
        $BroadcastIP = [System.Net.IPAddress]::Broadcast,

    # UDP port over which to broadcast magic packet (default: 7)
        [Parameter()]
        [Int16]
        $Port = 7
    )

    begin
    {
        # instantiate UDP client
        try
        {
            $UdpClient = [System.Net.Sockets.UdpClient]::new()
        }
        catch
        {
            Write-Error "Unable to instantiate UDP Client to send magic packets"
        }
    }

    process
    {
        foreach ($addr in $MacAddress)
        {
            # validate MAC address format or write error and continue
            if (!($addr -match '^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$'))
            {
                Write-Error "Invalid MAC address: $addr"
                continue
            }

            # convert MAC address to magic packet
            try
            {
                # construct byte-array from MAC address
                $MAC = $addr -split '[:-]' | ForEach-Object {
                    [Byte]"0x$_"
                }

                # construct magic packet
                # first 6 bytes = FF (255) then repeat MAC address 16 times
                [Byte[]]$magicPacket = (,0xFF * 6) + ($MAC * 16)
            }
            catch
            {
                Write-Error "Unable to process MAC address: $thisMacAddress"
                continue
            }

            # broadcast magic packets
            try
            {
                $UdpClient.Connect($BroadcastIP, $Port)
                $UdpClient.Send($magicPacket, $magicPacket.Length) | Out-Null
                Start-Sleep -Seconds 1
                $UdpClient.Send($magicPacket, $magicPacket.Length) | Out-Null
                Write-Verbose "Sent magic packet: Broadcast $addr over $BroadcastIP on port $Port (UDP)"
            }
            catch
            {
                Write-Error "Unable to send magic packet for '$addr'"
                continue
            }
        }
    }

    end
    {
        # dispose of UDP client
        $UdpClient.Close()
        $UdpClient.Dispose()
    }
}

Export-ModuleMember -Function Send-MagicPacket
