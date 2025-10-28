#!/bin/bash

function hmac_sha256 {
  key="$1"
  data="$2"
  echo -en "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | awk '{print $2}'
}


# 配置部分 - 请根据你的实际情况修改
VIRTUAL_HOSTED_STYLE="false"            # 云主机需打开虚拟主机模式，采用bucket.endpoint来访问
S3_ENDPOINT=""                       # MinIO 服务器地址和端口
ACCESS_KEY=""                           # MinIO 访问密钥
SECRET_KEY=""                           # MinIO 私有密钥
BUCKET_NAME=""                         # 存储桶名称
PROTOCOL="http://"                      # 使用 http 或 https. 如果 MinIO 使用 SSL/TLS，请设置为 "https"
REGION="us-east-1"                      # Minio默认区域
OBJECT_NAME=""                          # 要下载的路径+文件名
LOCAL_FILE="-"                          # 下载后保存到本地的文件名

function Minio { 
    S3_ENDPOINT="192.168.1.100:9900"  # MinIO 服务器地址和端口
    ACCESS_KEY="admin"       # MinIO 访问密钥
    SECRET_KEY="Admin!"       # MinIO 私有密钥
    BUCKET_NAME="bucket"          # 存储桶名称
    OBJECT_NAME="gitlab.json"         # 要下载的对象键 (Key)
    LOCAL_FILE="gitlab.json"             # 下载后保存到本地的文件名
}

function Seaweedfs() { 

    S3_ENDPOINT="192.168.1.100:8333"  # 替换为实际地址
    BUCKET_NAME="bucket"               # 目标桶名
    OBJECT_NAME="gitlab.json"
    OUTPUT_FILE="-"            # 本地保存路径
    ACCESS_KEY="admin"            # Minio访问密钥
    SECRET_KEY="Admin!"            # Minio私钥
    REGION="us-east-1"                      # Minio默认区域
}


function oss() { 
    VIRTUAL_HOSTED_STYLE="true" 
    BUCKET_NAME="bucket"               # 目标桶名
    OBJECT_NAME="gitlab.json"
    PROTOCOL="https://"                         # 使用 HTTP 或 HTTPS. 如果 MinIO 使用 SSL/TLS，请设置为 "https"
    S3_ENDPOINT="oss-cn-shanghai.aliyuncs.com"  # MinIO 服务器地址和端口
    ACCESS_KEY="LTXXXXXXXXXXXXXXXXX"       # MinIO 访问密钥
    SECRET_KEY="YYYYYYYYYYYYYYYYYY"        # MinIO 私有密钥
    REGION="cn-shanghai"                      # Minio默认区域
}


#选择对象存储
Minio

# 生成时间戳
X_AMZ_DATE=$(date -u +"%Y%m%dT%H%M%SZ")
X_AMZ_DATE=$(date -u +"%Y%m%dT%H%M00Z")
DATE_STAMP=$(date -u +"%Y%m%d")
HASHED_PAYLOAD='UNSIGNED-PAYLOAD'

# 1. 生成规范请求
SIGNED_HEADERS="host;x-amz-content-sha256;x-amz-date"
if [[ "$VIRTUAL_HOSTED_STYLE" == "true" ]]; then
    CANONICAL_URI="/${OBJECT_NAME}"
    CANONICAL_HEADERS="host:${BUCKET_NAME}.${S3_ENDPOINT#*//}\nx-amz-content-sha256:${HASHED_PAYLOAD}\nx-amz-date:${X_AMZ_DATE}\n"
    CANONICAL_REQUEST="GET\n${CANONICAL_URI}\n\n${CANONICAL_HEADERS}\n${SIGNED_HEADERS}\n${HASHED_PAYLOAD}"

else
    CANONICAL_URI="/${BUCKET_NAME}/${OBJECT_NAME}"
    PAYLOAD_HASH=$(echo -n "" | sha256sum | awk '{print $1}')  # 空负载用于GET请求
    CANONICAL_HEADERS="host:${S3_ENDPOINT#*//}\nx-amz-content-sha256:${PAYLOAD_HASH}\nx-amz-date:${X_AMZ_DATE}\n"
    CANONICAL_REQUEST="GET\n${CANONICAL_URI}\n\n${CANONICAL_HEADERS}\n${SIGNED_HEADERS}\n${PAYLOAD_HASH}"
fi

# 2. 生成待签名字符串
ALGORITHM="AWS4-HMAC-SHA256"
CREDENTIAL_SCOPE="${DATE_STAMP}/${REGION}/s3/aws4_request"
CANONICAL_REQUEST_HASH=$(echo -en "${CANONICAL_REQUEST}" | sha256sum | awk '{print $1}')

STRING_TO_SIGN="${ALGORITHM}\n${X_AMZ_DATE}\n${CREDENTIAL_SCOPE}\n${CANONICAL_REQUEST_HASH}"

# 3. 计算签名
DATE_KEY=$(hmac_sha256 "key:AWS4${SECRET_KEY}" "${DATE_STAMP}")
DATE_REGION_KEY=$(hmac_sha256 "hexkey:${DATE_KEY}" "${REGION}")
DATE_REGION_SERVICE_KEY=$(hmac_sha256 "hexkey:${DATE_REGION_KEY}" "s3")
SIGNING_KEY=$(hmac_sha256 "hexkey:${DATE_REGION_SERVICE_KEY}" "aws4_request")
SIGNATURE=$(hmac_sha256 "hexkey:${SIGNING_KEY}" "${STRING_TO_SIGN}")

DATE_KEY=$(echo -n "${DATE_STAMP}" | openssl dgst -sha256 -mac HMAC -macopt "key:AWS4${SECRET_KEY}" | awk '{print $2}')
DATE_REGION_KEY=$(echo -n "${REGION}" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${DATE_KEY}" | awk '{print $2}')
DATE_REGION_SERVICE_KEY=$(echo -n "s3" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${DATE_REGION_KEY}" | awk '{print $2}')
SIGNING_KEY=$(echo -n "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${DATE_REGION_SERVICE_KEY}" | awk '{print $2}')

# 4. 构造授权头
AUTHORIZATION_HEADER="${ALGORITHM} Credential=${ACCESS_KEY}/${CREDENTIAL_SCOPE}, SignedHeaders=${SIGNED_HEADERS}, Signature=${SIGNATURE}"

# 5. 执行下载请求
if [[ "$VIRTUAL_HOSTED_STYLE" == "true" ]]; then
curl -X GET "${PROTOCOL}${BUCKET_NAME}.${S3_ENDPOINT}/${OBJECT_NAME}" \
  -H "Host: ${BUCKET_NAME}.${S3_ENDPOINT#*//}" \
  -H "x-amz-date: ${X_AMZ_DATE}" \
  -H "Authorization: ${AUTHORIZATION_HEADER}" \
  -H "x-amz-content-sha256: ${HASHED_PAYLOAD}" \
#  -o "${OUTPUT_FILE}"
else
curl -X GET "${PROTOCOL}${S3_ENDPOINT}/${BUCKET_NAME}/${OBJECT_NAME}" \
  -H "Host: ${S3_ENDPOINT#*//}" \
  -H "x-amz-date: ${X_AMZ_DATE}" \
  -H "Authorization: ${AUTHORIZATION_HEADER}" \
  -H "x-amz-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" 
#    -o "${OUTPUT_FILE}"
fi

echo "File downloaded to: ${OUTPUT_FILE}"



