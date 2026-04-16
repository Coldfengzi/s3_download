# s3_download
## 使用shell及nginx njs组件下获取对象存储中的文件
> 目前测试下来可以下载Seaweedfs\Minio\OSS\OBS\US3中的文件。其他对象存储请自行测试！

## 配置awsign.js中对象存储相关参数
> 1. virtual_hosted_style 存储桶名称作为子域名的一部分，大部分云存储设置此项为true，Minio等私有化存储设置为false;
> 2. method 请求参数，目前只支持GET请求；
> 3. protocol 根据实际情况填写https或者http;
> 4. endpoint 根据实际情况填写,eg: oss-cn-hangzhou.aliyuncs.com;
> 5. region 根据实际情况填写,Minio等私有化存储一般设置为：us-east-1;
> 6. accessKeyId 不解释;
> 7. accessKeySecret 不解释;
> 8. bucket 不解释。
