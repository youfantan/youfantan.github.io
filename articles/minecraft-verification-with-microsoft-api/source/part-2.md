# 开始你的探索之旅

### Login with Microsoft Account

第一步自然是先让用户登陆微软账户，不过这玩意儿我们没法控制，所以说需要一个Web容器来加载这个页面，加载完成后再获取重定向的Url作为id获取下一步的Token。
根据wiki.vg的指南，这个url应该是这样的:
```
https://login.live.com/oauth20_authorize.srf
?client_id=00000000402b5328
&response_type=code
&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL 
&redirect_uri=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf
```
其中，client_id为minecraft在azure的服务名，response_type为返回结果类型，scope为验证服务的类型，redirect_uri为返回的重定向链接。(不要修改任意一条，这些都是minecraft在申请azure时被硬编码过的)。
在用户登陆Microsoft账户后，Microsoft OAuth将重定向到以`https://login.live.com/oauth20_desktop.srf?code=`开头的链接，=后(不包括=)就是我们要的code了。
下面是一个简单的示范，作者使用了Java Chromium Embedded Framework(JCEF)，基于Java编写。
```java
        CefApp.addAppHandler(new CefAppHandlerAdapter(null) {
            @Override
            public void stateHasChanged(org.cef.CefApp.CefAppState state) {
                if (state == CefApp.CefAppState.TERMINATED) System.exit(0);
            }
        });
        CefSettings settings = new CefSettings();
        settings.windowless_rendering_enabled = false;
        CefApp cefApp=CefApp.getInstance(settings);
        CefClient cefClient = cefApp.createClient();
        CefBrowser cefBrowser = cefClient.createBrowser(MicrosoftOAuthUrl, false, false);
        //MicrosoftOAuthUrl为上面拼接好的链接
        getContentPane().add(cefBrowser.getUIComponent(), BorderLayout.CENTER);
        pack();
        setTitle("Test For MSA");
        setSize(1260, 720);
        setVisible(true);
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                CefApp.getInstance().dispose();
                dispose();
            }
        });
        cefClient.addDisplayHandler(new CefDisplayHandler() {
            @Override
            public void onAddressChange(CefBrowser cefBrowser, CefFrame cefFrame, String s) {
                if (s.contains("https://login.live.com/oauth20_desktop.srf?code=")){
                    System.out.println(s.substring(s.indexOf("=")+1));
                }
            }

            @Override
            public void onTitleChange(CefBrowser cefBrowser, String s) {

            }

            @Override
            public boolean onTooltip(CefBrowser cefBrowser, String s) {
                return false;
            }

            @Override
            public void onStatusMessage(CefBrowser cefBrowser, String s) {

            }

            @Override
            public boolean onConsoleMessage(CefBrowser cefBrowser, CefSettings.LogSeverity logSeverity, String s, String s1, int i) {
                return false;
            }
        });
```

### Get Access Token

这一步就是获取Access Token，具体原理如图：
<img src="img/User-Client.png">  
<a href="document/User-Client.pdf" target="_Blank">下载PDF</a>  
向[Microsoft OAuth](https://login.live.com/oauth20_desktop.srf)发送一个`POST`请求，`MIME`负载类型为`application/x-www-form-urlencoded`，下面是一个例子：

```
    "client_id=00000000402b5328" +
    "&code=硬  核  马  赛  克" +
    "&grant_type=authorization_code" +
    "&redirect_uri=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf" +
    "&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL";
```
服务器POST回传JSON应该这个格式：

```json
   "token_type": "bearer",
   "expires_in": 86400,
   "scope": "service::user.auth.xboxlive.com::MBI_SSL",
   "access_token": [token],
   "refresh_token": [refresh_token],
   "user_id": [user_id],
   "foci": "1"
```

按照这个格式传一个请求即可，这里是一个简单的示范，基于Java编写。

```java
        URL ConnectUrl=new URL(MicrosoftOAuthDesktopUrl);
        HttpURLConnection connection= (HttpURLConnection) ConnectUrl.openConnection();
        String param="client_id=00000000402b5328" +
                "&code=" +code+
                "&grant_type=authorization_code" +
                "&redirect_uri=https%3A%2F%2Flogin.live.com%2Foauth20_desktop.srf" +
                "&scope=service%3A%3Auser.auth.xboxlive.com%3A%3AMBI_SSL";
                //here is your code above
        connection.setDoInput(true);
        connection.setDoOutput(true);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type","application/x-www-form-urlencoded");
        BufferedWriter wrt=new BufferedWriter(new OutputStreamWriter(connection.getOutputStream()));
        wrt.write(param);
        wrt.flush();
        wrt.close();
        BufferedInputStream reader=new BufferedInputStream(connection.getInputStream());
        byte[] bytes=new byte[1024];
        while ((reader.read(bytes))>0){
            System.out.println(new String(bytes));
        }
```

根据wiki.vg的解释加自己的猜测，服务器的Response的用途如下：
+ token_type:注册azure service时的硬编码服务名 *可能存在错误*
+ expires_in:令牌时效
+ scope:登陆类型 *可能存在错误*
+ access_token:校验令牌
+ refresh_token:刷新时效用的令牌
+ user_id:请求的Microsoft用户id *可能存在错误*
+ foci:??? ~~太抽象了~~

### Refresh Your AccessToken

为了不让用户每次登陆都加载一边及其缓慢的OAuth Authorize服务，可以使用上章的refresh_token来刷新token的使用时效，只需在刚刚的url发送一个`POST`请求，`MIME`负载类型为`application/x-www-form-urlencoded`的请求即可。那么直接上代码：

```java
        URL ConnectUrl=new URL(MicrosoftOAuthDesktopUrl);
        HttpURLConnection connection= (HttpURLConnection) ConnectUrl.openConnection();
        String param="client_id=00000000402b5328" +
                "&refresh_token=" +refresh_token+
                "&grant_type=refresh_token" +
                "&redirect_uri=https://login.live.com/oauth20_desktop.srf" +
                "&scope=service::user.auth.xboxlive.com::MBI_SSL";
                //here is your refresh token above
        connection.setDoInput(true);
        connection.setDoOutput(true);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type","application/x-www-form-urlencoded");
        BufferedWriter wrt=new BufferedWriter(new OutputStreamWriter(connection.getOutputStream()));
        wrt.write(param);
        wrt.flush();
        wrt.close();
        BufferedInputStream reader=new BufferedInputStream(connection.getInputStream());
        byte[] bytes=new byte[1024];
        while ((reader.read(bytes))>0){
            System.out.println(new String(bytes));
        }
```

### Get XBox Live Token

现在将要获取XBL Token用于下一步的XSTS Token，向[XBL](https://user.auth.xboxlive.com/user/authenticate)发送一个`POST`请求，`MIME`负载类型为`application/json`，负载中写入如下内容：

```json
{
    "Properties": {
        "AuthMethod": "RPS",
        "SiteName": "user.auth.xboxlive.com",
        "RpsTicket": [access_token]
    },
    "RelyingParty": "http://auth.xboxlive.com",
    "TokenType": "JWT"
 }
```

返回值如下：

```json
 {
   "IssueInstant":"2021-01-16T09:50:18.8729196Z",
   "NotAfter":"2021-01-30T09:50:18.8729196Z",
   "Token":"token",
   "DisplayClaims":{
      "xui":[
         {
            "uhs":"uhs"
         }
      ]
   }
 }
```

提取Token键和uhs键内容即可。下面是一个简单的示范，基于Java编写：

```java
        URL ConnectUrl=new URL(XBLUrl);
        String param=null;
        JSONObject xbl_param=new JSONObject(true);
        JSONObject xbl_properties=new JSONObject(true);
        xbl_properties.put("AuthMethod","RPS");
        xbl_properties.put("SiteName","user.auth.xboxlive.com");
        xbl_properties.put("RpsTicket",access_token);
        //here is your access token above
        xbl_param.put("Properties",xbl_properties);
        xbl_param.put("RelyingParty","http://auth.xboxlive.com");
        xbl_param.put("TokenType","JWT");
        param=JSON.toJSONString(xbl_param);
        HttpURLConnection connection= (HttpURLConnection) ConnectUrl.openConnection();
        connection.setDoInput(true);
        connection.setDoOutput(true);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type","application/json");
        System.out.println(param);
        BufferedWriter wrt=new BufferedWriter(new OutputStreamWriter(connection.getOutputStream()));
        wrt.write(param);
        wrt.flush();
        wrt.close();
        BufferedInputStream reader=new BufferedInputStream(connection.getInputStream());
        byte[] bytes=new byte[1024];
        while ((reader.read(bytes))>0){
            System.out.println(new String(bytes));
        }
```

### Get XSTS Token

这是Microsoft OAuth的最后一步，在XSTS上验证并获取Token和uhs。像XBL一样，不过这次的Url是[XSTS](https://xsts.auth.xboxlive.com/xsts/authorize)，发送一个`POST`请求，`MIME`负载类型为`application/json`，格式如下：

```json
 {
    "Properties": {
        "SandboxId": "RETAIL",
        "UserTokens": [
            "xbl_token"
        ]
    },
    "RelyingParty": "rp://api.minecraftservices.com/",
    "TokenType": "JWT"
 }
```

返回值如下：

```json
{
    "IssueInstant":"2021-01-16T11:22:58.250852Z",
    "NotAfter":"2021-01-17T03:22:58.250852Z",
    "Token":"token",
    "DisplayClaims":{
        "xui":[
            {
                "uhs":"uhs"
            }
        ]
    }
}
```

提取Token键和uhs键内容即可，下面是一个简单的示范，基于Java编写：

```java
        URL ConnectUrl=new URL(XSTSUrl);
        String param=null;
        List<String> tokens=new ArrayList<>();
        tokens.add("token");//here is your xbl token above
        JSONObject xbl_param=new JSONObject(true);
        JSONObject xbl_properties=new JSONObject(true);
        xbl_properties.put("SandboxId","RETAIL");
        xbl_properties.put("UserTokens",JSONArray.parse(JSON.toJSONString(tokens)));
        xbl_param.put("Properties",xbl_properties);
        xbl_param.put("RelyingParty","rp://api.minecraftservices.com/");
        xbl_param.put("TokenType","JWT");
        param=JSON.toJSONString(xbl_param);
        HttpURLConnection connection= (HttpURLConnection) ConnectUrl.openConnection();
        connection.setDoInput(true);
        connection.setDoOutput(true);
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Content-Type","application/json");
        BufferedWriter wrt=new BufferedWriter(new OutputStreamWriter(connection.getOutputStream()));
        wrt.write(param);
        wrt.flush();
        wrt.close();
        BufferedInputStream reader=new BufferedInputStream(connection.getInputStream());
        byte[] bytes=new byte[1024];
        while ((reader.read(bytes))>0){
            System.out.println(new String(bytes));
        }
```