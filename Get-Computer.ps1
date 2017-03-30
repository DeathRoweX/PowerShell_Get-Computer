<#
.SYNOPSIS
    Retrieves 'common' information from remote computers

.PARAMETER ComputerName
    Computername of computer to gather application list.

.EXAMPLE
    . .\Get-Computer.ps1
    PS C:\> Get-Computer Computer1, Computer2
#>
function get-Computer{
  [cmdletbinding()]

  param(
      [parameter(Mandatory=$true, position=1)]
      [string[]]$ComputerName
  )

  foreach ($Computer in $ComputerName){
      try{
      
          Write-Verbose "Establishing Connection to $($Computer)"
          $opt = New-CimSessionOption -Protocol Dcom
          $session = New-CimSession -ComputerName $Computer -SessionOption $opt -ea Stop

          Write-Verbose "Collecting Data from $($Computer)"
          $os = Get-CimInstance -ClassName win32_operatingsystem -CimSession $session
          $sys = Get-CimInstance -ClassName win32_ComputerSystem -CimSession $session
          $cpu = Get-CimInstance -ClassName win32_processor -CimSession $session
          $disk = Get-CimInstance -ClassName win32_logicaldisk -CimSession $session
          $net = Get-CimInstance -ClassName win32_NetworkAdapterconfiguration -CimSession $session
          $site = (nltest /server:$Computer /dsgetsite 2>&1)[0]
          $aliasOut = netdom computername $Computer /enum
          if($aliasOut.count -gt 5){
            for($i = 2; $i -lt $aliasOut.count-2; $i++){
              $alias += $alias[$i] | ?{$_ -notlike "$($Computer)*"}
            }
          }

          #Create hash table
          $properties = @{
              ComputerName = $Computer
              Status = 'Connected'
              Site = $site
              Alias = $alias
              Manufacturer = $sys.Manufacturer
              OS = $os.Caption
              InstallDate = $os.InstallDate
              LastReboot = $os.LastBootUpTime
              NumCPU = if($cpu.gettype().isarray){$cpu.NumberofCores.count}else{$cpu.NumberOfCores}
              TotalMemory = "{0:N2} GB" -f ($os.TotalVisibleMemorySize / 1MB)
          }

           # Add all disks to the hash table
           $disk | ?{$_.drivetype -eq 3} | %{
              $properties.add("Volume_$($_.DeviceID[0])", "$([math]::Round($_.FreeSpace/1GB, 2))/$([math]::Round($_.Size/1GB, 2)) GB Available")
           }

           # Add all ip addresses to the hash table
           $net | ?{$_.IPEnabled} | %{$i=0}{$properties.add("IpAddress$($i)", $_.IPAddress[0]); $i++}

      } catch {

          # cannot connect
          write-verbose "Cannot Connect to $Computer"

          # create empty table
          $properties = @{
              ComputerName = $Computer
              Status = 'Not Connected'
              Site = ""
              Alias = ""
              Manufacturer = ""
              OS = ""
              InstallDate = ""
              LastReboot = ""
              NumCPU = ""
              TotalMemory = ""
              Disk = ""
              IPAddress = ""
          }

      } finally{

          # place hashtable into object
          $obj = New-Object -TypeName psobject -Property $properties

          # write-out object
          Write-Output $obj
      }
  }
}
