<#
  2017-05-17
  Sistema de copias de seguridad automáticas
  Osiris Matiz Zapata
  osirismatiz@yahoo.es
  
  Ejecutar con privilegios de administrador:
  %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe
  Escribir:
  Set-ExecutionPolicy RemoteSigned
  Responder:
  y
  #>
  
  
function GetTargetFolders(){
    [xml]$configFile = Get-Content ($Script:scriptPath + '\BackupSystem_config.xml')
    [array]$targetFolders = @($configFile.configuration.appSettings.targetFolders.targetFolder)
    return $targetFolders
}


function GetSourceFolders(){
    [xml]$configFile = Get-Content ($Script:scriptPath + '\BackupSystem_config.xml')
    [array]$sourceFolders = @($configFile.configuration.appSettings.sourceFolders.sourceFolder)
    return $sourceFolders
}


function GetSourceMessages(){
    [xml]$messagesFile = Get-Content ($Script:scriptPath + '\BackupSystem_message.xml')
    [array]$sourceMessages = @($messagesFile.resourceMessages.resourceMessage.message)
    return $sourceMessages
}


function InitValidateMessages(){ 
    [object]$objectMessages = @()
    [int]$index = 0
    
    foreach ($item in GetSourceMessages) 
    { 
        [object]$oMessages = New-Object System.Object
        $oMessages | Add-Member –Type NoteProperty –Name Index –Value $index 
        $oMessages | Add-Member –Type NoteProperty –Name Code –Value $item.code 
        $oMessages | Add-Member –Type NoteProperty –Name Message –Value $item.InnerXml 
        $oMessages | Add-Member –Type NoteProperty –Name Param –Value ''
        $objectMessages += $oMessages 
        $index++
    }
    return $objectMessages
}


function GetProcessMessage([string]$code){
    [string]$message = $Script:validatorMessages | Where-Object {$_.Code -eq $code} | Select -ExpandProperty Message
    return $message
}


function SetProcessMessage([string]$code, [string]$message, [string]$detail){  
    [object]$oData = New-Object System.Object
    $oData | Add-Member –Type NoteProperty –Name Code –Value $code 
    $oData | Add-Member –Type NoteProperty –Name Message –Value $message
    $oData | Add-Member –Type NoteProperty –Name Details –Value $detail
    return $oData
}


function GetSizeElement([string]$element){
    $colItems = (Get-ChildItem $element -Recurse | Measure-Object -Property length -sum)
    return $colItems.Property.Length
}


function CreateTraceLog([string]$processLog){
    [int]$widthFile = 4096
    [string]$encodingFile = 'Default' #"UTF8"
    [string]$logDate = Get-Date -format 'yyyy-MM-dd HH:mm:ss'
    [string]$logFile = $Script:scriptPath + '\' + 'BackupSystem_trace.log'
    '{0} {1}' -f $logDate, $processLog  | Out-File -filepath $logFile -Append -Encoding $encodingFile -Width $widthFile    
}


function IsValidFolder([string]$typeItem, [string]$folderToValidate){
    [bool]$isValid = $true;
    switch ($typeItem) 
    { 
        'source' {
            if(!(Test-Path($folderToValidate))){
                $Script:failProcessMessages += SetProcessMessage '101' (GetProcessMessage('101')) $folderToValidate
                CreateTraceLog ((GetProcessMessage '101') + ' ' + $folderToValidate)
                $isValid = $false;
            }
            elseif((GetSizeElement($folderToValidate)) -le 0){
                $Script:failProcessMessages += SetProcessMessage '102' (GetProcessMessage('102')) $folderToValidate
                CreateTraceLog ((GetProcessMessage '102') + ' ' + $folderToValidate)
                $isValid = $false;
            }
            break;
        }
        'target' {
            if(!(Test-Path($folderToValidate))){
                $Script:failProcessMessages += SetProcessMessage '105' (GetProcessMessage('105')) $folderToValidate
                CreateTraceLog ((GetProcessMessage '105') + ' ' + $folderToValidate)
                $isValid = $false;
            }
            break;
        } 
        default {
            CreateTraceLog ('Otro mensaje de error')
            break;
        }
    }
    return $isValid;
}


function CreateTargetDate($targetFolder){
    Try{ 
        if(Test-Path($targetFolder)){
            CreateTraceLog ('Ya existe la carpeta fecha destino' + $targetFolder)
            return $true;
        }
        else{
            New-Item -Path $targetFolder -ItemType directory -Force > $nul
            CreateTraceLog ('Se creo correctamente la carpeta fecha destino' + $targetFolder)
            return $true;
        }
    }
    Catch [System.Exception]{ 
        $Script:failProcessMessages += SetProcessMessage '106' (GetProcessMessage('106')) ($targetFolder + '\' + $compressFile)
        CreateTraceLog ((GetProcessMessage '106') + ' ' + $targetFolder)
        return $false;
    }
}


function CompressFolder([string]$targetZip, [string]$sourceFolder){
    Try{
        [string]$pathZip = ($Script:scriptPath + '\7za.exe')
        [string]$excludeZip = ($Script:scriptPath + '\BackupSystem_exclude.txt')
        [string]$argumentsZip = ('a -r -tzip -xr@"{0}" "{1}" "{2}"' -f $excludeZip, $targetZip, $sourceFolder)
        Start-process -FilePath $pathZip -ArgumentList $argumentsZip -Wait -WindowStyle Hidden #-NoNewWindow
        Start-Sleep -m 1000
        CreateTraceLog ((GetProcessMessage '001') + ' ' + $sourceFolder)
    }
    Catch [System.Exception]{     
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName    
        $Script:failProcessMessages += SetProcessMessage '103' (GetProcessMessage('103')) ($ErrorMessage + ' ' + $FailedItem)
        CreateTraceLog ((GetProcessMessage '103') + ' ' + $sourceFolder)
    }    
}


function CopyCompress([string]$sourceFile, [string]$targetFolder){
    Try {
        if(!(Test-Path($sourceFile))){
            $Script:failProcessMessages += SetProcessMessage '104' (GetProcessMessage('104')) ($ErrorMessage + ' ' + $FailedItem)
            CreateTraceLog ((GetProcessMessage '104') + ' ' + $sourceFile)
            return $false;
        }
        else{
            Copy-Item $sourceFile -Destination $targetFolder -Force 
            Start-Sleep -m 1000
            CreateTraceLog ((GetProcessMessage '002') + ' ' + $sourceFile)
            return $true;
        }
    }
    Catch [System.Exception]{
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName    
        $Script:failProcessMessages += SetProcessMessage '106' (GetProcessMessage('106')) ($ErrorMessage + ' ' + $FailedItem)
        CreateTraceLog ((GetProcessMessage '106') + ' ' + $targetFolder)
        return $false;
    }
}


function DeleteLocalCompress($targetZip){
    Try{
        if(Test-Path($targetZip)){
            Remove-Item -Path $targetZip -Force
            Start-Sleep -m 1000
            CreateTraceLog ('Se elimina correctamente el comprimido local temporal ' + $targetZip)
        }
    }
    Catch [System.Exception]{
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName    
        $Script:failProcessMessages += SetProcessMessage '109' (GetProcessMessage('109')) ($ErrorMessage + ' ' + $FailedItem)
        CreateTraceLog ((GetProcessMessage '109') + ' ' + $targetZip)
    }
}


function ProcessFolder([string]$folderName){
    [string]$zipDate = Get-Date -format "yyyy-MM-dd"
    [string]$tempFolder = Split-Path $folderName -Leaf
    [string]$zipTarget = (Get-ChildItem Env:Temp).Value + '\' +  $zipDate + '_' + $tempFolder  + '.zip'
    [string]$targetName = $null
    
    [bool]$isValidTarget = $false
    [bool]$isCreateTarget = $false
    [bool]$isCopyCompress = $false

    CompressFolder $zipTarget $folderName 

    foreach ($itemTarget in GetTargetFolders)
    { 
        $isValidTarget = IsValidFolder 'target' $itemTarget
        
        if($isValidTarget){
            $targetName = $itemTarget + '\' + $zipDate
            $isCreateTarget = CreateTargetDate($targetName)

            if($isCreateTarget){
                $isCopyCompress = CopyCompress $zipTarget $targetName
                if($isCopyCompress){
                    DeleteLocalCompress $zipTarget
                }

            }
        }
    }
}



function Main(){
    Clear

    Write-Host "Inicio: "(Get-Date).ToString() -Fore yellow -Back blue

    [object]$Script:validatorMessages = InitValidateMessages
    [object]$Script:failProcessMessages = @()
    [bool]$validProcess = $false
    [string]$div = '-' * 35
    
    CreateTraceLog ($div  + ' Inicio del proceso ' + $div )
    foreach ($itemFolder in GetSourceFolders) 
    { 
        $validProcess = IsValidFolder 'source' $itemFolder
        
        if($validProcess){ 
            ProcessFolder $itemFolder 
        }
    }

    if(($Script:failProcessMessages -eq "") -or ($Script:failProcessMessages -eq [String]::Empty) -or ($Script:failProcessMessages -eq $null)){
	    $Script:failProcessMessages += SetProcessMessage '003' (GetProcessMessage('003')) ''
        CreateTraceLog (GetProcessMessage '003')
    }
    else{
	    $Script:failProcessMessages += SetProcessMessage '112' (GetProcessMessage('112')) ''
        CreateTraceLog (GetProcessMessage '112')
    }
    
    CreateTraceLog ($div  + ' Fin del proceso ' + $div)
	 
	#Enviar por correo esta informacion del proceso
	Write-Host "`r`nContenido del correo"
	$Script:failProcessMessages | Sort-Object Code | Select -Property Code, Message, Details -Unique | Format-Table -AutoSize
	
    Write-Host "Fin: " (Get-Date).ToString() -Fore yellow -Back blue
}

$Script:scriptPath = split-path -parent $MyInvocation.MyCommand.Definition;

Main
