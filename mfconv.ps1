foreach($mf in dir -Recurse makefile) {
    $text = Get-Content $mf -Encoding Default
    $text = $text | Select-String -Pattern "^[^#]" 

    #$text = [System.Text.Regularexpressions.Regex]::Replace(([string]::Join("`n", $text)), '\s*\\\n', ' ', "Singleline")

    $text = $text -replace '#.*', ''
    $text = $text -replace '!ifdef\s*(.*)', 'if($1)'
    $text = $text -replace '!ifndef\s*(.*)', 'if(NOT $1)'
    $text = $text -replace '!if\s*(.*)', 'if($1)'
    $text = $text -replace '!else', 'else()'
    $text = $text -replace '!elif\s*(.*)', 'elseif($1)'
    $text = $text -replace '!elseif', 'elseif()'
    $text = $text -replace '!endif', 'endif()'
    $text = $text -replace '!defined\((.+?)\)', 'NOT $1'
    $text = $text -replace 'defined\((.+?)\)', '$1'
    $text = $text -replace '\s\|\|\s', ' OR '
    $text = $text -replace '\|\|', ' OR '
    $text = $text -replace '\s&&\s', ' AND '
    $text = $text -replace '&&', ' AND '
    $text = $text -replace '\s*\\$', ''
    $text = $text -replace '\\', '/'
    $text = $text -replace '\s+#.*', ''
    $text = $text -replace '^\s+', ''
    $text = $text -replace '\s+$', ''

    $text = $text -replace 'SOURCES_C\s*=\s*(\w+)\s*', "SOURCES`r`n`$1"
    $text = $text -replace 'SOURCES_C\s*=', "SOURCES"
    $text = $text -replace 'SOURCES_CPP\s*=\s*(\w+)\s*', "SOURCES`r`n`$1"
    $text = $text -replace 'SOURCES_CPP\s*=', "SOURCES"
    $text = $text -replace 'SRCINCDIR_LOCAL\s*=\s*(\S+)', ""
    $text = $text -replace '-I', ""
    $text = $text -replace 'LOCAL_CCFLAGS\s*=\s*(\S+)', "add_definitions(`r`n`$1"
    $text = $text -replace 'SUB_DIRECTORIES\s*=\s*(\w+)\s*', "SUB_DIRECTORIES`r`n`$1"
    $text = $text -replace 'SUB_DIRECTORIES\s*=', "SUB_DIRECTORIES"
    $text = $text -replace '\$\(PATH2PROJROOT\)', '${CMAKE_SOURCE_DIR}'

    $text = $text -replace '\$\((\w+)\)', '${$1}'
#    $text = $text -replace '(\w+)\s*=\s*(\S+)', 'set($1 $2)'
    $text = $text -replace '!include.*', ''

    $text = $text -replace '^\s+', ''

    #fw_add_sources
    $text2 = ""
    $sources = @()
    $in_sources = $false
    foreach($textline in $text -split "`r`n") {
        if($textline -eq "SOURCES") {
            $in_sources = $true
            continue
        }
        if($in_sources) {
            if($textline -match "\w+\.(c|cpp)") {
                $sources += $textline
            } else {
                if($sources.Count) {
                    if($sources.Count -eq 1) {
                        $text2 += "fw_add_sources($sources)`r`n"
                    } else {
                        $text2 += "fw_add_sources(`r`n"
                        foreach($source in $sources) {
                            $text2 += "`t$source`r`n"
                        }
                        $text2 += ")`r`n"
                    }
                    $sources = @()
                }
                $text2 += "$textline`r`n"
            }
        } else {
            $text2 += "$textline`r`n"
        }
        if($textline -eq "") {
            $in_sources = $false
        }
    }
#    $text2 = $text

    #add_subdirectory
    $text3 = ""
    $in_subdirectory = $false
    foreach($textline in $text2 -split "`r`n") {
        if($textline -eq "SUB_DIRECTORIES") {
            $in_subdirectory = $true
            continue
        } elseif($textline -eq "") {
            $in_subdirectory = $false
        }
        if($in_subdirectory -and $textline -match "^\w+$") {
            $text3 += "add_subdirectory($textline)`r`n"
        } else {
            $text3 += "$textline`r`n"
        }
    }

    #indent
    $text4 = ""
    $level = 0
    foreach($textline in $text3 -split "`r`n") {
        if($textline -match "^endif\(.*") {
            $level--
        }
        if($textline -match "^else\(.*") {
            $level--
        }
        if($textline -match "^elseif\(.*") {
            $level--
        }
        for($i=0;$i -lt $level;++$i) {
            $text4 += "`t"
        }
        $text4 += $textline + "`r`n"
        if($textline -match "^if\(.*") {
            $level++
        }
        if($textline -match "^else\(.*") {
            $level++
        }
        if($textline -match "^elseif\(.*") {
            $level++
        }
    }

    $text4 = $text4 -replace '(\w+)\s*=.*', ''

    $outfile = $mf.DirectoryName + "\CMakeLists.txt"
    $text4.Trim("`r","`n") | Out-File $outfile -Encoding utf8
    [string]::Join("`r`n",(Get-Content $outfile)) | Set-Content $outfile
}
