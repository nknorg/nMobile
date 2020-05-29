package org.nkn.nmobile.app.util;

import android.content.Context;

public class IdGetter {
    public static final String anim = "anim";
    public static final String attr = "attr";
    public static final String color = "color";
    public static final String dimen = "dimen";
    public static final String drawable = "drawable";
    public static final String id = "id";
    public static final String layout = "layout";
    public static final String raw = "raw";
    public static final String string = "string";
    public static final String style = "style";
    public static final String styleable = "styleable";
    public static final String xml = "xml";
    public static final String sSysPkgName = "android";

    public static int getAnimId(Context context, String name) {
        return getId(context, name, anim);
    }

    public static int getAttrId(Context context, String name) {
        return getId(context, name, attr);
    }

    public static int getColorId(Context context, String name) {
        return getId(context, name, color);
    }

    public static int getDimenId(Context context, String name) {
        return getId(context, name, dimen);
    }

    public static int getDrawableId(Context context, String name) {
        return getId(context, name, drawable);
    }

    public static int getIdId(Context context, String name) {
        return getId(context, name, id);
    }

    public static int getLayoutId(Context context, String name) {
        return getId(context, name, layout);
    }

    public static int getRawId(Context context, String name) {
        return getId(context, name, raw);
    }

    public static int getStringId(Context context, String name) {
        return getId(context, name, string);
    }

    public static int getStyleId(Context context, String name) {
        return getId(context, name, style);
    }

    public static int getStyleableId(Context context, String name) {
        return getId(context, name, styleable);
    }

    public static int getXmlId(Context context, String name) {
        return getId(context, name, xml);
    }

    public static int getAnimId(Context context, String name, int idDef) {
        return getId(context, name, anim, idDef);
    }

    public static int getAttrId(Context context, String name, int idDef) {
        return getId(context, name, attr, idDef);
    }

    public static int getColorId(Context context, String name, int idDef) {
        return getId(context, name, color, idDef);
    }

    public static int getDimenId(Context context, String name, int idDef) {
        return getId(context, name, dimen, idDef);
    }

    public static int getDrawableId(Context context, String name, int idDef) {
        return getId(context, name, drawable, idDef);
    }

    public static int getIdId(Context context, String name, int idDef) {
        return getId(context, name, id, idDef);
    }

    public static int getLayoutId(Context context, String name, int idDef) {
        return getId(context, name, layout, idDef);
    }

    public static int getRawId(Context context, String name, int idDef) {
        return getId(context, name, raw, idDef);
    }

    public static int getStringId(Context context, String name, int idDef) {
        return getId(context, name, string, idDef);
    }

    public static int getStyleId(Context context, String name, int idDef) {
        return getId(context, name, style, idDef);
    }

    public static int getStyleableId(Context context, String name, int idDef) {
        return getId(context, name, styleable, idDef);
    }

    public static int getXmlId(Context context, String name, int idDef) {
        return getId(context, name, xml, idDef);
    }

    public static int getIdSys(Context context, String name, String type) {
        return getId(context, name, type, sSysPkgName);
    }

    public static int getIdSys(Context context, String name, String type, int idDef) {
        return getId(context, name, type, sSysPkgName, idDef);
    }

    public static int getId(Context context, String name, String type) {
        return getId(context, name, type, context.getPackageName());
    }

    public static int getId(Context context, String name, String type, int idDef) {
        return getId(context, name, type, context.getPackageName(), idDef);
    }

    public static int getId(Context context, String name, String type, String pkgName) {
        final int id = context.getResources().getIdentifier(name, type, pkgName);
        checkId(id, name, type, pkgName);
        return id;
    }

    public static int getId(Context context, String name, String type, String pkgName, int idDef) {
        final int id = context.getResources().getIdentifier(name, type, pkgName);
        return id == 0 ? idDef : id;
    }

    private static void checkId(int id, String name, String type, String pkgName) {
        if (id == 0) throw new RuntimeException("缺少id：" + pkgName + ".R." + type + "." + name);
    }
}
