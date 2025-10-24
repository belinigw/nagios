<#
.SYNOPSIS
    Verifica o status de um servico Windows cujo nome começa com um prefixo específico (ex: AVP.KES.)

.DESCRIPTION
    Este script foi criado para integração com Nagios (via NSClient++, NRPE ou check_nrpe).
    Ele procura servicos cujo nome inicie com um prefixo configurável e retorna:
        - OK se os servicos automaticos estiverem rodando
        - CRITICAL se algum servico automático estiver parado ou o prefixo Nao existir
        - WARNING se apenas servicos manuais forem encontrados

.PARAMETER Prefix
    Prefixo do nome do servico (padrão: "AVP.")

.PARAMETER IncludeManualServices
    Quando especificado, inclui servicos configurados como "Manual" na verificação.

.EXAMPLE
    .\check_avp_service.ps1 -Prefix "AVP.KES."

.NOTES
    Compatível com Windows Server 2012 ou superior.
    Autor: David Rivera Allegro (NagiosGenius)
#>

param(
    [string]$Prefix = "Kaspersky.",
    [switch]$IncludeManualServices
)

# --- Configuração básica ---
$ErrorActionPreference = "SilentlyContinue"
$exitcode = 3
$message = ""

# --- Obtém lista de servicos que correspondem ao prefixo ---
$services = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.DisplayName -like "$Prefix*" }

if (-not $services) {
    Write-Output "CRITICAL: Nenhum servico encontrado com prefixo '$Prefix'"
    exit 2
}

# --- Separa servicos automaticos e manuais ---
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
        Write-Output "WARNING: Apenas servicos manuais encontrados com prefixo '$Prefix' (" + ($manualList -join ", ") + ")"
        exit 1
    }

    Write-Output "UNKNOWN: Nao foi possivel determinar servicos para validacao com prefixo '$Prefix'"
    exit 3
}

# --- Verifica status dos servicos encontrados ---
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
    $message = "CRITICAL: servicos automaticos parados encontrados: " + ($stopped -join ", ")
    $exitcode = 2
} else {
    $message = "OK: servicos automaticos com prefixo '$Prefix' estao rodando (" + ($running -join ", ") + ")"
    $exitcode = 0
}

if (-not $IncludeManualServices -and $manualServices) {
    $manualNames = $manualServices | Select-Object -ExpandProperty Name
    $message += "; servicos manuais ignorados: " + ($manualNames -join ", ")
}

Write-Output $message
exit $exitcode