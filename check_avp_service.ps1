<#
.SYNOPSIS
    Verifica o status de um serviço Windows cujo nome começa com um prefixo específico (ex: AVP.KES.)

.DESCRIPTION
    Este script foi criado para integração com Nagios (via NSClient++, NRPE ou check_nrpe).
    Ele procura serviços cujo nome inicie com um prefixo configurável e retorna:
        - OK se o serviço estiver rodando
        - WARNING se estiver parado ou não existir

.PARAMETER Prefix
    Prefixo do nome do serviço (padrão: "AVP.")

.EXAMPLE
    .\check_avp_service.ps1 -Prefix "AVP.KES."

.NOTES
    Compatível com Windows Server 2012 ou superior.
    Autor: David Rivera Allegro (NagiosGenius)
#>

param(
    [string]$Prefix = "AVP."
)

# --- Configuração básica ---
$ErrorActionPreference = "SilentlyContinue"
$exitcode = 3
$message = ""

# --- Obtém lista de serviços que correspondem ao prefixo ---
$services = Get-Service | Where-Object { $_.Name -like "$Prefix*" }

if (-not $services) {
    Write-Output "WARNING: Nenhum serviço encontrado com prefixo '$Prefix'"
    exit 1
}

# --- Verifica status dos serviços encontrados ---
$stopped = @()
$running = @()

foreach ($svc in $services) {
    if ($svc.Status -eq "Running") {
        $running += $svc.Name
    } else {
        $stopped += $svc.Name
    }
}

# --- Monta a saída final ---
if ($stopped.Count -gt 0) {
    $message = "WARNING: Serviços parados encontrados: " + ($stopped -join ", ")
    $exitcode = 1
} else {
    $message = "OK: Todos os serviços com prefixo '$Prefix' estão rodando (" + ($running -join ", ") + ")"
    $exitcode = 0
}

Write-Output $message
exit $exitcode
