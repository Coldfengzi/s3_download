/* 
  创建待签名字符串 
var awsAccess = {
  virtual_hosted_style: false,
  method: 'GET',
  protocol: 'http://',
  endpoint: '192.168.1.100:9900',
  region: 'us-east-1',
  accessKeyId: 'admin',
  accessKeySecret: 'Admin!',
  bucket: 'bucket'
}
*/


var awsAccess = {
  virtual_hosted_style: true,
  method: 'GET',
  protocol: 'https://',
  endpoint: 'oss-cn-hangzhou.aliyuncs.com',
  region: 'cn-hangzhou',
  accessKeyId: 'LTXXXXXXXXXXXXXXXXX',
  accessKeySecret: 'YYYYYYYYYYYYYYYYYY',
  bucket: 'bucket'
}
 /**/



function sha256Hex(data) {
    return require('crypto').createHash('sha256').update(data).digest('hex');
}

function hmac_sha256(key, data, encoding) {
    return require('crypto').createHmac('sha256', key).update(data).digest(encoding || 'hex');
}

function getSignatureKey(secretKey, dateStamp, region, service) {
    let kDate = require('crypto').createHmac('sha256', "AWS4" + secretKey).update(dateStamp).digest();
    let kRegion = require('crypto').createHmac('sha256', kDate).update(region).digest();
    let kService = require('crypto').createHmac('sha256', kRegion).update(service).digest();
    let kSigning = require('crypto').createHmac('sha256', kService).update("aws4_request").digest();
    return kSigning;
}

function getAMZdate (r) {
  var currentDate = new Date();
  const xAmzDate = currentDate.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
  return xAmzDate;
}


function getProtocol (r) {
  return awsAccess.protocol;
}

function getEndpoint (r) {
    if (awsAccess.virtual_hosted_style)
    {
        return awsAccess.bucket + '.' + awsAccess.endpoint;
    }else{
        return awsAccess.endpoint;
    }
}

function getAMZContent (r) {
    if (awsAccess.virtual_hosted_style)
    {
        return "UNSIGNED-PAYLOAD";
    }else{
        return sha256Hex("");
    }
}


function getObject (r) {
    let firstObjectName = r.uri.split('/');
    firstObjectName.shift();
    firstObjectName.shift();
    return firstObjectName.join('/');
}

function getSignRequest(r) {
    let object = getObject(r); // 获取 URL 参数中的 object 名
    if (!object) {
        r.return(400, "Object parameter is required");
        return;
    }
    ngx.log(ngx.ERR, "Object: " + object);
    let region = awsAccess.region;

    // 时间戳
    let now = new Date();
    let X_AMZ_DATE = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
    let DATE_STAMP = X_AMZ_DATE.slice(0, 8);
    let signedHeaders = "host;x-amz-content-sha256;x-amz-date";
    let payloadHash = getAMZContent(r); 

    // Canonical Request
    if (awsAccess.virtual_hosted_style)
    {
        
        var canonicalUri = "/" + object;
        var canonicalHeaders = "host:" + awsAccess.bucket + "." + awsAccess.endpoint + 
                            "\nx-amz-content-sha256:" + payloadHash + 
                            "\nx-amz-date:" + X_AMZ_DATE + 
                            "\n";
    }else{
        var canonicalUri = "/" + awsAccess.bucket + "/" + object;
        var canonicalHeaders = "host:" + awsAccess.endpoint + 
                                "\nx-amz-content-sha256:" + payloadHash + 
                                "\nx-amz-date:" + X_AMZ_DATE + 
                                "\n";
    }
        let canonicalRequest = awsAccess.method + "\n" +
                           canonicalUri + "\n\n" +
                           canonicalHeaders + "\n" +
                           signedHeaders + "\n" +
                           payloadHash;

    ngx.log(ngx.ERR, "canonicalRequest: " + canonicalRequest);
    let canonicalRequestHash = sha256Hex(canonicalRequest);

    // StringToSign
    let algorithm = "AWS4-HMAC-SHA256";
    let credentialScope = DATE_STAMP + "/" + region + "/s3/aws4_request";
    let stringToSign = algorithm + "\n" +
                       X_AMZ_DATE + "\n" +
                       credentialScope + "\n" +
                       canonicalRequestHash;

    // 签名
    let signingKey = getSignatureKey(awsAccess.accessKeySecret, DATE_STAMP, region, "s3");
    let signature = require('crypto').createHmac('sha256', signingKey).update(stringToSign).digest('hex');

    let authorizationHeader = algorithm +
        " Credential=" + awsAccess.accessKeyId + "/" + credentialScope +
        ", SignedHeaders=" + signedHeaders +
        ", Signature=" + signature;

    // === 生成预签名 URL ===
    let signedUrl = `${awsAccess.protocol}${awsAccess.endpoint}${canonicalUri}?x-amz-date=${X_AMZ_DATE}&X-Amz-Signature=${signature}&X-Amz-Credential=${awsAccess.accessKeyId}/${credentialScope}`;

    return authorizationHeader;
}
function getCanonicalUri(r) {
    let object = getObject(r); // 获取 URL 参数中的 object 名

    // Canonical Request
    if (awsAccess.virtual_hosted_style)
    {
        var canonicalUri = "/" + object;
    }else{
        var canonicalUri = "/" + awsAccess.bucket + "/" + object;
    }
   
    return canonicalUri;
}
export default {getProtocol,getEndpoint,getAMZdate,getAMZContent,getSignRequest,getCanonicalUri};
