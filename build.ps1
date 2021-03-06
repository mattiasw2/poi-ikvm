Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not (Test-Path .\nuget.exe))
{
    Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile nuget.exe
}

$ikvm_version = '8.1.5717.0'

if (-not(Test-Path ikvm\))
{
#   Invoke-WebRequest -Uri 'https://sourceforge.net/projects/ikvm/files/latest/download?source=files' -OutFile ikvm.zip -UserAgent "NativeHost"
    Invoke-WebRequest -Uri "http://www.frijters.net/ikvmbin-$ikvm_version.zip" -OutFile ikvm.zip -UserAgent "NativeHost"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\ikvm.zip", "$PWD")
    Remove-Item ikvm.zip
    Get-Item ikvm* | select -Index 0 | Rename-Item -Path {$_.FullName} -NewName ikvm
}
#.\nuget.exe install IKVM

if (-not(Test-Path poi\))
{
$poi_base_url = �http://www-us.apache.org/dist/poi/release/bin/�

$href = ((Invoke-WebRequest �Uri $poi_base_url).Links | where {$_.href -like "*.zip"}).href

Invoke-WebRequest -Uri ($poi_base_url + $href) -OutFile poi.zip

[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\poi.zip", "$PWD")

Remove-Item poi.zip

Get-Item poi* | select -Index 0 | Rename-Item -Path {$_.FullName} -NewName poi
}

$poi_main = Get-ChildItem -Path poi | where {$_.Name -match '^poi-\d+\.\d+\.jar$'}

$version = $poi_main.BaseName.Substring("poi-".Length) + ".0"

$latestPublished = (.\nuget.exe list id:poi-ikvm) | where {$_ -imatch '^poi-ikvm\s'} | foreach {[Version]($_ -replace '^poi-ikvm\s(.*)$', '$1')}

if ($latestPublished -ne $null -and $latestPublished -ge [Version]$version)
{
    $version = (New-Object -TypeName Version -ArgumentList ($latestPublished.Major, $latestPublished.Minor, ($latestPublished.Build + 1))).ToString()
}


$vr = '[0-9.\-]+'

$libs = "commons-codec$($vr)jar|commons-collections$($vr)jar|commons-logging$($vr)jar|junit$($vr)jar|log4j$($vr)jar"

$new_libs = Get-ChildItem -Path .\poi\lib | select { $_.Name -imatch $libs } | where {$_ -eq $false}

if ($new_libs -ne $null)
{
    throw "This version of poi has new dependencies. The code below needs to be modified to determine whether to include them in the package"
}

$jars = @($($poi_main;(Get-ChildItem -Path .\poi\lib | where {$_ -inotmatch "junit$($vr)jar"})) | select -ExpandProperty FullName)

&.\ikvm\bin\ikvmc.exe -out:package\lib\net40\poi.dll -target:library $jars

$versionElement = Select-Xml -Path .\package\poi-ikvm.nuspec -XPath 'package/metadata/version'
$versionElement.Node.'#text' = $version
$versionElement.Node.OwnerDocument.Save("$PWD\package\poi-ikvm.nuspec")

$versionElement = Select-Xml -Path .\package\poi-ikvm.nuspec -XPath 'package/metadata/dependencies/dependency[@id=''IKVM'']'
$versionElement.Node.SetAttribute('version', $ikvm_version)
$versionElement.Node.OwnerDocument.Save("$PWD\package\poi-ikvm.nuspec")
