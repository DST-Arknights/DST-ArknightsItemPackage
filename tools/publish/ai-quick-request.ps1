# OpenAI Chat Completions 兼容的非流式快速请求。
# 配置优先读取项目根目录下的 .ai.env，再读取同名环境变量。

param(
    [string]$Prompt,
    [string]$ConfigPath,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

function Get-AIConfig {
    param(
        [string]$LocalConfigPath
    )

    $config = @{}
    if ($LocalConfigPath -and (Test-Path -LiteralPath $LocalConfigPath)) {
        foreach ($line in Get-Content -LiteralPath $LocalConfigPath -Encoding UTF8) {
            $text = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($text) -or $text.StartsWith('#')) {
                continue
            }

            $separator = $text.IndexOf('=')
            if ($separator -le 0) {
                throw "[阻断] AI 配置文件格式错误，应为 KEY=VALUE: $LocalConfigPath"
            }

            $name = $text.Substring(0, $separator).Trim()
            $value = $text.Substring($separator + 1).Trim()
            if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $config[$name] = $value
        }
    }

    $getValue = {
        param([string]$Name)

        $value = $null
        if ($config.ContainsKey($Name)) {
            $value = [string]$config[$Name]
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($Name)
        }
        return $value
    }

    $apiKey = & $getValue 'OPENAI_API_KEY'
    $baseUrl = & $getValue 'OPENAI_BASE_URL'
    $model = & $getValue 'OPENAI_MODEL'

    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        $baseUrl = 'https://api.openai.com/v1'
    }

    $missing = @()
    if ([string]::IsNullOrWhiteSpace($apiKey)) { $missing += 'OPENAI_API_KEY' }
    if ([string]::IsNullOrWhiteSpace($model)) { $missing += 'OPENAI_MODEL' }
    if ($missing.Count -gt 0) {
        $configHint = if ($LocalConfigPath) { $LocalConfigPath } else { '.ai.env' }
        throw @"
[阻断] 未配置 AI 请求参数: $($missing -join ', ')

请在以下任一位置配置：
  1. 被 .gitignore 忽略的本地文件: $configHint
  2. 当前用户或当前进程的环境变量: $($missing -join ', ')

OPENAI_BASE_URL 未配置时默认使用: https://api.openai.com/v1
"@
    }

    return @{
        ApiKey  = $apiKey
        BaseUrl = $baseUrl.TrimEnd('/')
        Model   = $model
    }
}

function Invoke-AIQuickRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [string]$LocalConfigPath
    )

    $config = Get-AIConfig -LocalConfigPath $LocalConfigPath
    $uri = "$($config.BaseUrl)/chat/completions"
    $body = @{
        model    = $config.Model
        messages = @(
            @{
                role    = 'user'
                content = $Text
            }
        )
        stream   = $false
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod `
            -Uri $uri `
            -Method Post `
            -Headers @{ Authorization = "Bearer $($config.ApiKey)" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body $body `
            -TimeoutSec 120
    }
    catch {
        $message = $_.Exception.Message
        if ($config.ApiKey) {
            $message = $message.Replace($config.ApiKey, '[REDACTED]')
        }
        throw "[失败] AI 请求失败: $message"
    }

    $content = $response.choices[0].message.content
    if ($content -is [array]) {
        $content = ($content | ForEach-Object {
            if ($_.text) { $_.text } else { $_.content }
        }) -join ''
    }
    if ([string]::IsNullOrWhiteSpace([string]$content)) {
        throw '[失败] AI 返回了空结果。'
    }
    return ([string]$content).Trim()
}

$defaultConfigPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.ai.env'
$effectiveConfigPath = if ($ConfigPath) { $ConfigPath } else { $defaultConfigPath }

if ($ValidateOnly) {
    Get-AIConfig -LocalConfigPath $effectiveConfigPath | Out-Null
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Prompt)) {
    throw '[阻断] 未提供 AI 请求内容。'
}

Invoke-AIQuickRequest -Text $Prompt -LocalConfigPath $effectiveConfigPath
