#!/bin/bash

# 检查ffprobe和jq是否可用
if ! command -v ffprobe &> /dev/null || ! command -v jq &> /dev/null; then
    echo "错误：ffprobe 或 jq 工具未安装，请先安装 FFmpeg 和 jq。"
    exit 1
fi

# 提示用户输入基本URL，并提供示例
echo "请输入基本URL，示例："
echo "http://example.com/video_[start-end].mp4"
echo "其中，[start-end] 是要替换的起始和结束数字部分。"

# 读取用户输入的基本URL
read -p "请输入基本URL: " baseurl

# 参数验证
if [ -z "$baseurl" ]; then
    echo "错误：未提供基本URL。"
    exit 1
fi

# 解析基本URL中的起始和结束数字
if [[ $baseurl =~ \[([0-9]+)-([0-9]+)\] ]]; then
    start=${BASH_REMATCH[1]}
    end=${BASH_REMATCH[2]}
else
    echo "错误：无法解析起始和结束数字。"
    exit 1
fi

# 确保结束值的位数与起始值相同，不足的话在前面添加0
end_length=${#end}
start_padded=$(printf "%0${end_length}d" "$start")
end_padded=$(printf "%0${end_length}d" "$end")

output_file="results.txt"

# 计算总数目
total=$((end_padded - start_padded + 1))
count=0

echo "开始检查视频分辨率..."

for ((number=start; number<=end; number++))
do
    number_padded=$(printf "%0${end_length}d" "$number")
    url=$(echo "$baseurl" | sed "s/\[$start-$end\]/$number_padded/")
    echo "正在检查视频: $url"
    res=$(ffprobe -user_agent "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36" -timeout 5000  -select_streams v -show_streams -v quiet -of csv="p=0" -of json -i "$url")

    # 检查是否成功获取了视频信息
    if [[ -z "$res" ]]; then
        echo "警告：未能获取视频信息。"
    else
        # 检查是否检测到分辨率和宽度
        if [[ $res == *'"height"'* && $res == *'"width"'* ]]; then
            height=$(jq -r '.streams[0].height' <<< "$res")
            width=$(jq -r '.streams[0].width' <<< "$res")
            rate=$(jq -r '.streams[0].avg_frame_rate' <<< "$res")
            echo "$number_padded[${width}x${height}] @ $rate, $url"
            echo "$number_padded[${width}x${height}] @ $rate, $url" >> "$output_file"
        else
            echo "警告：未能检测到视频分辨率或宽度。"
        fi
    fi

    # 更新进度
    count=$((count + 1))
    progress=$((count * 100 / total))
    echo "进度: $progress% 完成 ($count/$total)"
done

echo "视频分辨率检查完成。结果保存在: $output_file"
