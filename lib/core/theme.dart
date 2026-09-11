import 'package:flutter/material.dart';

const spikeRed=Color(0xFF94050A);
const spikeBg=Color(0xFFF1F1F1);
const spikePanel=Color(0xFFFFFFFF);
const spikeProductCard=Color(0xFFEAEAEA);
const spikeField=Color(0xFFE4E4E4);
const spikeMuted=Color(0xFFA9A9A9);
// Shared reference yellow used by address and checkout actions.
const spikeYellow=Color(0xFFF5B400);
const spikeDarkBg=Color(0xFF111111);
const spikeDarkPanel=Color(0xFF1D1D1D);

/// Styles that replace the ambient default (button themes, snack bar, input
/// hints) must carry the app font family; Material swaps DefaultTextStyle
/// wholesale, so a raw TextStyle here would fall back to the system font.
TextStyle spikeTextStyle({double? fontSize,FontWeight? fontWeight,Color? color})=>const TextStyle(fontFamily:'GraphikArabic',fontFamilyFallback:['Tahoma','Arial']).copyWith(fontSize:fontSize,fontWeight:fontWeight,color:color);

/// Pixel-matched spacing tokens from the reference customer frontend.
abstract final class SpikeSpacing {
  static const double xs=4;
  static const double sm=8;
  static const double md=12;
  static const double lg=16;
  static const double page=17;
  static const double xl=24;
  static const double xxl=32;

  static const EdgeInsets pageHorizontal=EdgeInsets.symmetric(horizontal:page);
  static const EdgeInsets pageList=EdgeInsets.fromLTRB(page,sm,page,xl);
  static const EdgeInsets card=EdgeInsets.all(16);
  static const EdgeInsets sheet=EdgeInsets.fromLTRB(page,lg,page,xl);
}

abstract final class SpikeRadius {
  static const double control=25;
  static const double card=16;
  static const double sheet=24;
}

TextTheme _textTheme(Brightness b)=>TextTheme(
  titleLarge:TextStyle(fontSize:21,fontWeight:FontWeight.w700,height:1.25,color:b==Brightness.dark?Colors.white:null),
  titleMedium:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:b==Brightness.dark?Colors.white:null),
  bodyMedium:TextStyle(fontSize:12,fontWeight:FontWeight.w700,height:1.45,color:b==Brightness.dark?Colors.white:null),
  bodySmall:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:b==Brightness.dark?Colors.white70:spikeMuted),
);

ThemeData _theme(Brightness brightness){
  final dark=brightness==Brightness.dark;
  final surface=dark?spikeDarkPanel:Colors.white;
  final field=dark?spikeDarkPanel:spikeField;
  final onSurface=dark?Colors.white:Colors.black;
  return ThemeData(
    useMaterial3:true,
    brightness:brightness,
    scaffoldBackgroundColor:dark?spikeDarkBg:spikeBg,
    colorScheme:ColorScheme.fromSeed(seedColor:spikeRed,brightness:brightness),
    fontFamily:'GraphikArabic',
    fontFamilyFallback:const ['Tahoma','Arial'],
    splashFactory:InkRipple.splashFactory,
    textTheme:_textTheme(brightness),
    iconTheme:IconThemeData(color:onSurface),
    appBarTheme:AppBarTheme(backgroundColor:Colors.transparent,foregroundColor:onSurface,elevation:0,scrolledUnderElevation:0),
    navigationBarTheme:NavigationBarThemeData(height:76,backgroundColor:surface,indicatorColor:Colors.transparent,labelBehavior:NavigationDestinationLabelBehavior.alwaysShow),
    bottomSheetTheme:BottomSheetThemeData(backgroundColor:dark?spikeDarkBg:spikeBg,modalBackgroundColor:dark?spikeDarkBg:spikeBg,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(SpikeRadius.sheet)))),
    dividerTheme:DividerThemeData(color:onSurface.withValues(alpha:.10),space:1,thickness:1),
    listTileTheme:ListTileThemeData(iconColor:onSurface,textColor:onSurface,contentPadding:const EdgeInsets.symmetric(horizontal:SpikeSpacing.md,vertical:SpikeSpacing.xs)),
    inputDecorationTheme:InputDecorationTheme(
      filled:true,
      fillColor:field,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
      hintStyle:spikeTextStyle(color:spikeMuted,fontSize:12,fontWeight:FontWeight.w700),
      labelStyle:spikeTextStyle(color:onSurface.withValues(alpha:.70),fontSize:12,fontWeight:FontWeight.w700),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(SpikeRadius.control),borderSide:BorderSide.none),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(SpikeRadius.control),borderSide:const BorderSide(color:spikeRed,width:1.2)),
      errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(SpikeRadius.control),borderSide:const BorderSide(color:spikeRed)),
      focusedErrorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(SpikeRadius.control),borderSide:const BorderSide(color:spikeRed,width:1.2)),
    ),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(0,38),padding:const EdgeInsets.symmetric(horizontal:20),textStyle:spikeTextStyle(fontSize:12,fontWeight:FontWeight.w700),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(SpikeRadius.control)))),
    outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(minimumSize:const Size(0,38),padding:const EdgeInsets.symmetric(horizontal:16),textStyle:spikeTextStyle(fontSize:12,fontWeight:FontWeight.w700),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(SpikeRadius.control)))),
    textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(textStyle:spikeTextStyle(fontSize:12,fontWeight:FontWeight.w500))),
    snackBarTheme:SnackBarThemeData(backgroundColor:dark?Colors.white:Colors.black,contentTextStyle:spikeTextStyle(color:dark?Colors.black:Colors.white,fontSize:12,fontWeight:FontWeight.w700),behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(SpikeRadius.control))),
  );
}

final spikeTheme=_theme(Brightness.light);
final spikeDarkTheme=_theme(Brightness.dark);
