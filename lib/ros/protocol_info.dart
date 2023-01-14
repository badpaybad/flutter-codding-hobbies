class ProtocolInfo {
  final String name;
  final List<dynamic> params;
  ProtocolInfo(this.name, this.params);

  @override
  String toString(){
    return "$name ${params.join(",")}";
  }
}
