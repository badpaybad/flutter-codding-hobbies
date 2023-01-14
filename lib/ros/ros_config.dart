import 'dart:io';

class RosConfig {
   String name="flutterlocalhost";
   String masterUri="http://127.0.0.1:11311";
   dynamic host=InternetAddress.anyIPv4; //can be: 0.0.0.0
   int port=0;

  RosConfig({String ? name,String ?masterUri,dynamic ?host_ip_domain_anyipv4,int ?port}){
        if(name!=null) this.name=name;
        if(masterUri!=null) this.masterUri=masterUri;
        if(host_ip_domain_anyipv4!=null) this.host=host_ip_domain_anyipv4;
        if(port!=null) this.port=port;
  }

  @override
  String toString(){
    return "$name # $masterUri # $host:$port";
  }
}
