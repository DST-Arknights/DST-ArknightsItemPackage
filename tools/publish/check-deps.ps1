# 依赖检查（跨 DST mod 项目可复用）
# 检查必需的系统工具是否可用。

function Test-RequiredTools {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Required
    )

    $allOk = $true
    $installHints = @{
        'git' = @{
            check  = { Get-Command git -ErrorAction SilentlyContinue }
            hint   = "从 https://git-scm.com/downloads/win 安装 Git"
        }
    }

    foreach ($tool in $Required) {
        $info = $installHints[$tool]
        if (-not $info) {
            Write-Warning "工具 '$tool' 没有注册安装提示"
            $result = Get-Command $tool -ErrorAction SilentlyContinue
            if (-not $result) {
                Write-Error "[缺失] 未找到必需工具: $tool。请安装后重试。"
                $allOk = $false
            }
        }
        else {
            $result = & $info.check
            if (-not $result) {
                Write-Error "[缺失] 未找到必需工具: $tool`n  -> $($info.hint)"
                $allOk = $false
            }
            else {
                Write-Host "[就绪]  $tool"
            }
        }
    }

    if (-not $allOk) {
        throw "缺少必需工具，请在安装后重新运行发布脚本。"
    }
}
