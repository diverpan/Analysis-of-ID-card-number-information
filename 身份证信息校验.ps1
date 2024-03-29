# 定义传入参数（含默认参数）
param(
    # 定义默认参数
    $FilePath = "$($PSScriptRoot)\ids.txt",
    $CodeFile = "$($PSScriptRoot)\身份证前六位地区码对照表_20240221.csv"
)

# 身份证信息获取方法
function id_info_get([string]$id){
    $address_code = $id.Substring(0,6)
    $address_info = $hash_code_province["$address_code"] + "-" + $hash_code_city["$address_code"] + "-" + $hash_code_district["$address_code"] 
    
    $birth_code = $id.Substring(6,8)
    $birth_info = $birth_code.Substring(0,4) + "年" + $birth_code.Substring(4,2) + "月" + $birth_code.Substring(6,2) + "日"

    if($id.Substring(16,1)%2 -eq 1){
        $gender_info = "男"
    }elseif($id.Substring(16,1)%2 -eq 0){
        $gender_info = "女"
    }

    return $id + "," + $address_info + "," + $birth_info + "," + $gender_info + ","
}

# 身份证号码校验方法
function id_verify([string]$id){
    # 设置数字字符集
    $charSet = "0123456789".ToCharArray()
    # 定义校验码字符集（按顺序）
    $check_num_char = @('1','0','X','9','8','7','6','5','4','3','2')
    # 定义校验结果（0为校验有误，1为校验无误）
    $flag = 1

    # 1、长度判断
    if($id.Length -ne 18){
        Write-Host "$($id)：长度不满足身份证18位的要求"  -ForegroundColor Yellow 
        $flag = 0
        return $flag
        break
    }

    # 2、每一位的字符使用判断
    $chars = $null
    $chars = $id.ToCharArray()
    for($j=0;$j -lt $chars.count-1;$j++){
        if($chars[$j] -notin $charSet ){
            Write-Host "$($id)：第$($j)字符使用超出定义范围"  -ForegroundColor Yellow 
            $flag = 0 
            return $flag
            break
        }
    }
    if( !(($chars[-1] -in $charSet) -or ($chars[-1] -eq "x") -or ($chars[-1] -eq "X"))){
        Write-Host "$($id)：最后一个字符使用超出定义范围"  -ForegroundColor Yellow 
        $flag = 0
        return $flag
        break
    }

    # 3、出生日期合理性检查
    $birth_String = $id.Substring(6,4) + "-" + $id.Substring(10,2) + "-" + $id.Substring(12,2)
    if([int](get-date -UFormat "%Y%m%d") -lt [int]$id.Substring(6,8)){
        Write-Host "$($id)：出生日期异常（未来出生日期）"  -ForegroundColor Yellow 
        $flag = 0
        return $flag
        break        
    }

    try {
        [datetime]::ParseExact($birth_String,'yyyy-MM-dd',$null)|out-null
    } catch {
        Write-Host "$($id)：出生日期异常（非法出生日期）"  -ForegroundColor Yellow 
        $flag = 0
        return $flag
        break
    }
    
    # 4、地区码合理性检查
    if($id.Substring(0,6) -notin $area_code){
        Write-Host "$($id)：地区码异常" -ForegroundColor Yellow
        $flag = 0
        return $flag
        break
    }

    # 5、校验码核验（根据《中华人民共和国国家标准》）
    $queue = 0
    $queue =(([int]$chars[0]-48)*7   + ([int]$chars[1]-48)*9  + ([int]$chars[2]-48)*10 + ([int]$chars[3]-48)*5 +`
             ([int]$chars[4]-48)*8   + ([int]$chars[5]-48)*4  + ([int]$chars[6]-48)*2  + ([int]$chars[7]-48)*1 +`
             ([int]$chars[8]-48)*6   + ([int]$chars[9]-48)*3  + ([int]$chars[10]-48)*7 + ([int]$chars[11]-48)*9 +`
             ([int]$chars[12]-48)*10 + ([int]$chars[13]-48)*5 + ([int]$chars[14]-48)*8 + ([int]$chars[15]-48)*4 +`
             ([int]$chars[16]-48)*2)%11
    if($check_num_char[$queue] -ne $chars[17]){
        Write-Host "$($id)：校验码异常" -ForegroundColor Yellow 
        $flag = 0
        return $flag
        break
    }

    # 没有任何问题则返回$flag（值为1）
    return $flag    
}

# 定义主函数/方法
function check_id_info{
    param(
        # 定义默认参数
        $file_path,
        $code_file = "$($PSScriptRoot)\身份证前六位地区码对照表_20240221.csv"
    )

    $date_and_time = get-date -UFormat "%Y%m%d%H%M%S"
    $export_data = @()

    # 读取身份证信息文本
    $ids = Get-Content "$file_path" -Encoding UTF8
    $address_infos = import-csv -path $code_file -Encoding Default
    $area_code = $address_infos|Select-Object -ExpandProperty '区域编号'
    
    # 构造哈希表（身份证前6位对应的省、市、区级单位）
    $hash_code_province = @{}
    $hash_code_city = @{}
    $hash_code_district = @{}
    foreach($line in $address_infos){
        $hash_code_province.add($line.'区域编号',$line.'省/直辖市')
        $hash_code_city.add($line.'区域编号',$line.'市/自治州')
        $hash_code_district.add($line.'区域编号',$line.'区/县')
    }

    # 执行分析判断
    if($ids.count -eq 1){
        if(id_verify($ids) -eq 1){
            $temp_info = $null
            $temp_info = (id_info_get($ids)).split(",")
            $export_data += New-Object psobject -Property @{
                id      = $temp_info[0];
                area    = $temp_info[1];
                birth   = $temp_info[2];
                gender  = $temp_info[3];
                remarks = $temp_info[4]
            }
        }
    }elseif($ids.count -gt 1){
        for($i =0;$i -lt $ids.count;$i++){
            if(id_verify($ids[$i]) -eq 1){
                $temp_info = $null
                $temp_info = (id_info_get($ids[$i])).Split(",")
                $export_data += New-Object psobject -Property @{
                    id      = $temp_info[0];
                    area    = $temp_info[1];
                    birth   = $temp_info[2];
                    gender  = $temp_info[3];
                    remarks = $temp_info[4]
                }
            }
        }
    }elseif($ids.count -lt 1){
        write-host "没有任何输入"
    }
    $export_data |Export-csv -Path "$PSScriptRoot\results_$($date_and_time).csv" -Encoding Default -NoTypeInformation
    Write-Host $PSScriptRoot
}

# 最终执行命令
check_id_info -file_path $FilePath -code_file $CodeFile

################################################################  说      明  ################################################################
#    两种用法
# 1、powershell ISE 运行此脚本
#    然后使用命令 “ check_id_info -file_path $FilePath -code_file $CodeFile ” 处理
#    其中 -code_file 有默认参数
# 2、cmd、powershell 或其他脚本调用
#    使用命令“身份证信息校验.ps1 -FilePath 身份证id文件路径 -CodeFile 区划代码文件路径 ”处理
#    其中 -CodeFile 有默认参数
##############################################################################################################################################
