function Send-MagicPacket
{
    [CmdletBinding()]
    param
    (
    # Array of MAC addresses for which to construct magic packets
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$')]
        [String[]]
        $MacAddress,

    # Broadcast IP address (default: all subnets --> 255.255.255.255)
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
                Write-Warning "Unable to process MAC address: $thisMacAddress"
                continue
            }

            # broadcast magic packet
            try
            {
                $UdpClient.Connect($BroadcastIP, $Port)
                $UdpClient.Send($magicPacket, $magicPacket.Length) | Out-Null
                Write-Verbose "Sent magic packet: Broadcast $addr over $BroadcastIP on port $Port (UDP)"
            }
            catch
            {
                Write-Warning "Unable to send magic packet for '$addr'"
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