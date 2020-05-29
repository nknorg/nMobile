-keep class net.sqlcipher.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

-ignorewarnings
-keep class com.umeng.** {*;}

 -keepclassmembers class * {
    public <init> (org.json.JSONObject);
 }

 -keepclassmembers enum * {
     public static **[] values();
     public static ** valueOf(java.lang.String);
 }

 -keep public class com.bitkeep.miner.R$*{
 public static final int *;
 }

-keep class  android.view.WindowInsets{}
-keep class  android.view.View{}
-keep class  android.graphics.Insets{}
-keepnames class * extends android.view.View
-keepnames class * extends android.app.Fragment
-keepnames class * extends android.support.v4.app.Fragment
-keepnames class * extends androidx.fragment.app.Fragment
-keep class android.support.v4.view.ViewPager{
  *;
}
-keep class android.support.v4.view.ViewPager$**{
  *;
}
-keep class androidx.viewpager.widget.ViewPager{
  *;
}
-keep class androidx.viewpager.widget.ViewPager$**{
  *;
}
-keep class net.sqlcipher.** { *; }

