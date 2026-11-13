import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
String peso(num amount)=>NumberFormat.currency(locale:'en_PH',symbol:'₱',decimalDigits:2).format(amount);
String stamp(DateTime d)=>DateFormat('MMM d, yyyy • h:mm a').format(d);
void errorMessage(BuildContext context,Object e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
class MetricTile extends StatelessWidget {final String title,value;final IconData icon;const MetricTile({super.key,required this.title,required this.value,required this.icon});@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:const Color(0xFF166534)),const SizedBox(height:10),Text(title,style:Theme.of(context).textTheme.labelMedium),const SizedBox(height:4),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(value,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)))])));}
