<#
.SYNOPSIS
    Verifica o status de um serviço Windows cujo nome começa com um prefixo específico (ex: AVP.KES.)

.DESCRIPTION
    Este script foi criado para integração com Nagios (via NSClient++, NRPE ou check_nrpe).
    Ele procura serviços cujo nome inicie com um prefixo configurável e retorna:
        - OK se os serviços automáticos estiverem rodando
        - CRITICAL se algum serviço automático estiver parado ou o prefixo não existir
        - WARNING se apenas serviços manuais forem encontrados

.PARAMETER Prefix
    Prefixo do nome do serviço (padrão: "AVP.")

.PARAMETER IncludeManualServices
    Quando especificado, inclui serviços configurados como "Manual" na verificação.

.EXAMPLE
    .\check_avp_service.ps1 -Prefix "AVP.KES."

.NOTES
    Compatível com Windows Server 2012 ou superior.
    Autor: David Rivera Allegro (NagiosGenius)
#>

param(
    [string]$Prefix = "AVP.",
    [switch]$IncludeManualServices
)

# --- Configuração básica ---
$ErrorActionPreference = "SilentlyContinue"
$exitcode = 3
$message = ""

# --- Obtém lista de serviços que correspondem ao prefixo ---
$services = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -like "$Prefix*" }

if (-not $services) {
    Write-Output "CRITICAL: Nenhum serviço encontrado com prefixo '$Prefix'"
    exit 2
}

# --- Separa serviços automáticos e manuais ---
$automaticServices = $services | Where-Object { $_.StartMode -eq "Auto" -or $_.DelayedAutoStart }
$manualServices = $services | Where-Object { $_.StartMode -ne "Auto" -and -not $_.DelayedAutoStart }

if (-not $IncludeManualServices) {
    $servicesToCheck = $automaticServices
} else {
    $servicesToCheck = $services
}

if (-not $servicesToCheck) {
    $manualList = $manualServices | Select-Object -ExpandProperty Name
    if ($manualList) {
        Write-Output "WARNING: Apenas serviços manuais encontrados com prefixo '$Prefix' (" + ($manualList -join ", ") + ")"
        exit 1
    }

    Write-Output "UNKNOWN: Não foi possível determinar serviços para validação com prefixo '$Prefix'"
    exit 3
}

# --- Verifica status dos serviços encontrados ---
$stopped = @()
$running = @()

foreach ($svc in $servicesToCheck) {
    if ($svc.State -eq "Running") {
        $running += $svc.Name
    } else {
        $stopped += $svc.Name
    }
}

# --- Monta a saída final ---
if ($stopped.Count -gt 0) {
    $message = "CRITICAL: Serviços automáticos parados encontrados: " + ($stopped -join ", ")
    $exitcode = 2
} else {
    $message = "OK: Serviços automáticos com prefixo '$Prefix' estão rodando (" + ($running -join ", ") + ")"
    $exitcode = 0
}

if (-not $IncludeManualServices -and $manualServices) {
    $manualNames = $manualServices | Select-Object -ExpandProperty Name
    $message += "; Serviços manuais ignorados: " + ($manualNames -join ", ")
}

Write-Output $message
exit $exitcode
