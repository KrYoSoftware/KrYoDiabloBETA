$Config = @{
    VMName      = 'Windows 10'  # Edit this to match your existing VM. If you don't have a VM with this name, it will be created.
    VMMemory    = 8192MB    # Set appropriately
    VMCores     = 4         # likewise
    MinRsrc     = 80000000  # We don't really know what these values do - my GPU reports 100,000,000 available units...
    MaxRsrc     = 100000000 # I suspect in the current implementation they do nothing, but this is known to work - play around if you like!
    OptimalRsrc = 100000000
}

### actual execution
try {

    # Get VM host capabilities
    $VMHost = Get-VMHost
    # Get highest VM config version available
    $VMVersion = $VMHost.SupportedVmVersions[$VMHost.SupportedVmVersions.Count - 1]

    # Get existing VM if it exists
    $VMObject = (Get-VM -Name $Config.VMName -ErrorAction SilentlyContinue)

    # Create VM if it doesn't already exist
    if (-not $VMObject) {
        $NewVM = @{
            Name               = $Config.VMName
            MemoryStartupBytes = $Config.VMMemory
            Generation         = 2
            Version            = $VMVersion
        }
        New-VM @NewVM
    }

    # Enable VM features required for this to work
    $SetParams = @{
        VMName                    = $Config.VMName
        GuestControlledCacheTypes = $true
        LowMemoryMappedIoSpace    = 1Gb
        HighMemoryMappedIoSpace   = 32GB
        AutomaticStopAction       = 'TurnOff'
        CheckpointType            = 'Disabled'
    }
    Set-VM @SetParams
    # Disable secure boot
    Set-VMFirmware -VMName $Config.VMName -EnableSecureBoot 'Off'

    # Parameters for vAdapter
    $GPUParams = @{
        VMName                  = $Config.VMName
        MinPartitionVRAM        = $Config.MinRsrc
        MaxPartitionVRAM        = $Config.MaxRsrc
        OptimalPartitionVRAM    = $Config.OptimalRsrc
        MinPartitionEncode      = $Config.MinRsrc
        MaxPartitionEncode      = $Config.MaxRsrc
        OptimalPartitionEncode  = $Config.OptimalRsrc
        MinPartitionDecode      = $Config.MinRsrc
        MaxPartitionDecode      = $Config.MaxRsrc
        OptimalPartitionDecode  = $Config.OptimalRsrc
        MinPartitionCompute     = $Config.MinRsrc
        MaxPartitionCompute     = $Config.MaxRsrc
        OptimalPartitionCompute = $Config.OptimalRsrc
    }

    # Get adapter if it exists
    $VMAdapter = (Get-VMGpuPartitionAdapter -VMName $Config.VMName -ErrorAction SilentlyContinue)

    # Add adapter if not present, update if present
    if ($VMAdapter) {
        Set-VMGpuPartitionAdapter @GPUParams
    } else {
        Add-VMGpuPartitionAdapter @GPUParams
    }

} catch {
    Write-Error "Something went wrong with creation. Error details below:"
    Write-Error $PSItem.ErrorDetails
    throw $PSItem
}