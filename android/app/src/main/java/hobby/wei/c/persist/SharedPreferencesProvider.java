/*
 * Copyright (C) 2015-present, Wei Chou(weichou2010@gmail.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package hobby.wei.c.persist;

import android.annotation.SuppressLint;
import android.content.ContentProvider;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.UriMatcher;
import android.database.ContentObserver;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Binder;
import android.text.TextUtils;

import org.nkn.mobile.app.App;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

/**
 * &lt;provider<br/>
 * &nbsp;&nbsp;&nbsp;&nbsp;android:name="com.xxx.SharedPreferencesProvider"<br/>
 * &nbsp;&nbsp;&nbsp;&nbsp;android:authorities="packagename.MPSPREF"<br/>
 * &nbsp;&nbsp;&nbsp;&nbsp;android:exported="true"<br/>
 * &nbsp;&nbsp;&nbsp;&nbsp;android:multiprocess="false" /&gt;<br/>
 *
 * @author Wei Chou(weichou2010@gmail.com) 2015/9/2
 */
public class SharedPreferencesProvider extends ContentProvider {
    public static final String AUTHORITY            = App.Companion.withPackageNamePrefix("MPSPREF");

    private static final String SEP                 = "/";
    private static final String SCHEME              = ContentResolver.SCHEME_CONTENT + ":" + SEP + SEP;
    private static final String NODE_TEXT           = "*";
    private static final String REPLACEMENT         = SEP + "%s";

    private static final String KEY                 = "key";
    private static final String VALUE               = "value";

    public static final String APPLY                = "apply";
    public static final String COMMIT               = "commit";
    public static final byte[] FLAG_STRING_SET      = "flag_string_set".getBytes();
    public static final byte[] FLAG_BOOL_TRUE       = new byte[]{1};
    public static final byte[] FLAG_BOOL_FALSE      = new byte[]{0};

    /**e.g: content://com.xxx.MPSPREF/(p|g)/(i|s|...)/fileName,
     * 变更反馈，
     * e.g: content://com.xxx.MPSPREF/fileName/(key|N)/(r|c|i|...)**/
    private static final String URI_FORMAT_3S		= SCHEME + AUTHORITY + REPLACEMENT + REPLACEMENT + REPLACEMENT;
    /**e.g: content://com.xxx.MPSPREF/(r|c)/fileName**/
    private static final String URI_FORMAT_2S 		= SCHEME + AUTHORITY + REPLACEMENT + REPLACEMENT;
    /**观察者监听值变更**/
    private static final String URI_NOTIFY_OBSERVER = SCHEME + AUTHORITY + REPLACEMENT;

    private static final String sPut                = "p";
    private static final String sGet                = "g";
    private static final String sRemove             = "r";
    private static final String sClear              = "c";
    private static final String sClearKey4Notify    = "N";

    private static final String sInt                = "i";
    private static final String sFloat              = "f";
    private static final String sLong               = "l";
    private static final String sBool               = "b";
    private static final String sString             = "s";
    private static final String sStrSet          	= "e";
    private static final String sAll                = "a";
    private static final String sContains           = "c";

    private static final int PUT_INT                = 0;
    private static final int PUT_FLOAT              = 1;
    private static final int PUT_LONG               = 2;
    private static final int PUT_BOOL               = 3;
    private static final int PUT_STRING             = 4;
    private static final int PUT_STR_SET         	= 5;

    private static final int GET_INT                = 6;
    private static final int GET_FLOAT              = 7;
    private static final int GET_LONG               = 8;
    private static final int GET_BOOL               = 9;
    private static final int GET_STRING             = 10;
    private static final int GET_STR_SET           	= 11;
    private static final int GET_ALL           	    = 12;
    private static final int GET_CONTAINS           = 13;

    private static final int REMOVE                 = 14;
    private static final int CLEAR                  = 15;

    public static final int NOTIFY_CHANGE_INT       = 16;
    public static final int NOTIFY_CHANGE_FLOAT     = 17;
    public static final int NOTIFY_CHANGE_LONG      = 18;
    public static final int NOTIFY_CHANGE_BOOL      = 19;
    public static final int NOTIFY_CHANGE_STRING    = 20;
    public static final int NOTIFY_CHANGE_STR_SET   = 21;

    public static final int NOTIFY_REMOVE           = 22;
    public static final int NOTIFY_CLEAR            = 23;

    private static final UriMatcher sUriMatcher     = new UriMatcher(UriMatcher.NO_MATCH);

    static {
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sInt + SEP + NODE_TEXT, PUT_INT);
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sFloat + SEP + NODE_TEXT, PUT_FLOAT);
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sLong + SEP + NODE_TEXT, PUT_LONG);
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sBool + SEP + NODE_TEXT, PUT_BOOL);
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sString + SEP + NODE_TEXT, PUT_STRING);
        sUriMatcher.addURI(AUTHORITY, sPut + SEP + sStrSet + SEP + NODE_TEXT, PUT_STR_SET);

        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sInt + SEP + NODE_TEXT, GET_INT);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sFloat + SEP + NODE_TEXT, GET_FLOAT);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sLong + SEP + NODE_TEXT, GET_LONG);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sBool + SEP + NODE_TEXT, GET_BOOL);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sString + SEP + NODE_TEXT, GET_STRING);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sStrSet + SEP + NODE_TEXT, GET_STR_SET);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sAll + SEP + NODE_TEXT, GET_ALL);
        sUriMatcher.addURI(AUTHORITY, sGet + SEP + sContains + SEP + NODE_TEXT, GET_CONTAINS);

        sUriMatcher.addURI(AUTHORITY, sRemove + SEP + NODE_TEXT, REMOVE);
        sUriMatcher.addURI(AUTHORITY, sClear + SEP + NODE_TEXT, CLEAR);

        //******************************************************************//
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sInt, NOTIFY_CHANGE_INT);
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sFloat, NOTIFY_CHANGE_FLOAT);
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sLong, NOTIFY_CHANGE_LONG);
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sBool, NOTIFY_CHANGE_BOOL);
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sString, NOTIFY_CHANGE_STRING);
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sStrSet, NOTIFY_CHANGE_STR_SET);

        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sRemove, NOTIFY_REMOVE);
        //NODE_TEXT + SEP + sClearKey4Notify + SEP + sClear无法通过匹配
        sUriMatcher.addURI(AUTHORITY, NODE_TEXT + SEP + NODE_TEXT + SEP + sClear, NOTIFY_CLEAR);
    }

    public static Uri getUri4PutInt(String name) {
        return makeUri(sPut, sInt, name);
    }

    public static Uri getUri4PutFloat(String name) {
        return makeUri(sPut, sFloat, name);
    }

    public static Uri getUri4PutLong(String name) {
        return makeUri(sPut, sLong, name);
    }

    public static Uri getUri4PutBoolean(String name) {
        return makeUri(sPut, sBool, name);
    }

    public static Uri getUri4PutString(String name) {
        return makeUri(sPut, sString, name);
    }

    public static Uri getUri4PutStringSet(String name) {
        return makeUri(sPut, sStrSet, name);
    }

    public static Uri getUri4GetInt(String name) {
        return makeUri(sGet, sInt, name);
    }

    public static Uri getUri4GetFloat(String name) {
        return makeUri(sGet, sFloat, name);
    }

    public static Uri getUri4GetLong(String name) {
        return makeUri(sGet, sLong, name);
    }

    public static Uri getUri4GetBoolean(String name) {
        return makeUri(sGet, sBool, name);
    }

    public static Uri getUri4GetString(String name) {
        return makeUri(sGet, sString, name);
    }

    public static Uri getUri4GetStringSet(String name) {
        return makeUri(sGet, sStrSet, name);
    }

    public static Uri getUri4GetAll(String name) {
        return makeUri(sGet, sAll, name);
    }

    public static Uri getUri4GetContains(String name) {
        return makeUri(sGet, sContains, name);
    }

    public static Uri getUri4Remove(String name) {
        return makeUri(sRemove, null, name);
    }

    public static Uri getUri4Clear(String name) {
        return makeUri(sClear, null, name);
    }

    public static Uri getUri4NotifyObserver(String name) {
        if (TextUtils.isEmpty(name)) throw newException4NullName();
        return Uri.parse(String.format(URI_NOTIFY_OBSERVER, name));
    }

    private static Uri makeUri(String action, String type, String name) {
        if (TextUtils.isEmpty(name)) throw newException4NullName();
        return Uri.parse(type == null ? String.format(URI_FORMAT_2S, action, name) :
                String.format(URI_FORMAT_3S, action, type, name));
    }

    /** e.g: content://com.xxx.MPSPREF/fileName/(key|N)/(r|c|i|...) **/
    private static Uri makeNotifyUri(String actionOrType, String name, String key) {
        return Uri.parse(String.format(URI_FORMAT_3S, name, key, actionOrType));
    }

    public static int parseNotifyType(Uri uri) {
        return sUriMatcher.match(uri);
    }

    /**
     * 解析通知<code>Uri</code>表示的{@link SharedPreferences}的文件名和存储记录的key.
     *
     * @param uri 当{@link SharedPreferences}的key-value对有变动时，本组件会发出通知
     * {@link ContentResolver#notifyChange(Uri, ContentObserver) notifyChange(Uri, ContentObserver)}，
     *            本参数是通知的第一个参数。
     * @return string[0]为name, string[1]为key
     */
    public static String[] parseNotifyNameAndKey(Uri uri) {
        final List<String> list = uri.getPathSegments();
        switch (sUriMatcher.match(uri)) {
            case NOTIFY_CHANGE_INT:
            case NOTIFY_CHANGE_FLOAT:
            case NOTIFY_CHANGE_LONG:
            case NOTIFY_CHANGE_BOOL:
            case NOTIFY_CHANGE_STRING:
            case NOTIFY_CHANGE_STR_SET:
            case NOTIFY_REMOVE:
                return new String[]{list.get(list.size() - 3), list.get(list.size() - 2)};
            case NOTIFY_CLEAR:
                return new String[]{list.get(list.size() - 3), null};
            default:
                throw newException4IllegalUri();
        }
    }

    @Override
    public boolean onCreate() {
        return false;
    }

    @Override
    public String getType(Uri uri) {
        return ContentResolver.CURSOR_ITEM_BASE_TYPE + SEP + "spref";
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        checkPermission();
        //不可能为null, 前面已经作了检查
        final String name = uri.getLastPathSegment();
        final SharedPreferences spref = getContext().getSharedPreferences(name, Context.MODE_PRIVATE);
        final MatrixCursor cursor = new MatrixCursor(new String[]{VALUE});
        switch (sUriMatcher.match(uri)) {
            case GET_INT:
                cursor.addRow(new Object[]{spref.getInt(projection[0], Integer.valueOf(selectionArgs[0]))});
                break;
            case GET_FLOAT:
                cursor.addRow(new Object[]{spref.getFloat(projection[0], Float.valueOf(selectionArgs[0]))});
                break;
            case GET_LONG:
                cursor.addRow(new Object[]{spref.getLong(projection[0], Long.valueOf(selectionArgs[0]))});
                break;
            case GET_BOOL:
                cursor.addRow(new Object[]{spref.getBoolean(projection[0], Boolean.valueOf(selectionArgs[0])) ?
                        FLAG_BOOL_TRUE : FLAG_BOOL_FALSE});
                break;
            case GET_STRING:
                cursor.addRow(new Object[]{spref.getString(projection[0], selectionArgs[0])});
                break;
            case GET_STR_SET:
                final Set<String> set = spref.getStringSet(projection[0], Collections.<String>emptySet());
                for (String s : set) {
                    cursor.addRow(new Object[]{s});
                }
                break;
            case GET_ALL:
                final MatrixCursor cursorAll = new MatrixCursor(new String[]{KEY, VALUE});
                final Map<String, ?> map = spref.getAll();
                if (map != null) {
                    final Set<? extends Map.Entry<String, ?>> entries = map.entrySet();
                    for (Map.Entry<String, ?> entry : entries) {
                        final Object value = entry.getValue();
                        if (value instanceof Set) {  //StringSet
                            cursorAll.addRow(new Object[]{entry.getKey(), FLAG_STRING_SET});
                        } else if (value instanceof Boolean) {
                            cursorAll.addRow(new Object[]{entry.getKey(), (Boolean) value ? FLAG_BOOL_TRUE : FLAG_BOOL_FALSE});
                        } else {
                            cursorAll.addRow(new Object[]{entry.getKey(), value});
                        }
                    }
                }
                return cursorAll;
            case GET_CONTAINS:
                cursor.addRow(new Object[]{spref.contains(projection[0]) ? FLAG_BOOL_TRUE : FLAG_BOOL_FALSE});
                break;
            default:
                throw newException4UnsupportedOperation();
        }
        return cursor;
    }

    @SuppressLint("CommitPrefEdits")
    @Override
    public int update(final Uri uri, ContentValues values, String commitOrApply, String[] selectionArgs) {
        checkPermission();
        //不可能为null, 前面已经作了检查
        final String name = uri.getLastPathSegment();
        final SharedPreferences spref = getContext().getSharedPreferences(name, Context.MODE_PRIVATE);
        final Editor editor = spref.edit();
        Uri uri4Notify = null;
        String key = null;
        boolean keyNotEmpty = false;
        boolean valueChanged = false;
        switch (sUriMatcher.match(uri)) {
            case PUT_INT:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        final int newValue = values.getAsInteger(key);
                        valueChanged = newValue != spref.getInt(key, getNotEqualWith(0, newValue));
                        editor.putInt(key, newValue);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sInt, name, key);
                }
                break;
            case PUT_FLOAT:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        final Float newValue = values.getAsFloat(key);
                        valueChanged = !equals(newValue, spref.getFloat(key, getNotEqualWith(0f, newValue)));
                        editor.putFloat(key, newValue);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sFloat, name, key);
                }
                break;
            case PUT_LONG:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        final long newValue = values.getAsLong(key);
                        valueChanged = newValue != spref.getLong(key, getNotEqualWith(0, newValue));
                        editor.putLong(key, newValue);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sLong, name, key);
                }
                break;
            case PUT_BOOL:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        final boolean newValue = values.getAsBoolean(key);
                        valueChanged = newValue ^ spref.getBoolean(key, getNotEqualWith(false, newValue));
                        editor.putBoolean(key, newValue);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sBool, name, key);
                }
                break;
            case PUT_STRING:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        final String newValue = values.getAsString(key);
                        valueChanged = !equals(newValue, spref.getString(key, getNotEqualWith(null, newValue)));
                        editor.putString(key, newValue);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sString, name, key);
                }
                break;
            case PUT_STR_SET:
                final Set<String> newValue = new HashSet<String>();
                for (String k : values.keySet()) {
                    //HashMap的key可以为null, 即HashSet的element可以为null, 同时也是[无序的]
                    if (!TextUtils.isEmpty(k) && (key == null || k.length() < key.length())) {
                        key = k;
                        keyNotEmpty = true;
                    }
                    newValue.add(values.getAsString(k)); //注意是小k
                }
                if (keyNotEmpty) {
                    valueChanged = !equals(newValue, spref.getStringSet(key, getNotEqualWith(null, newValue)));
                    editor.putStringSet(key, newValue);
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sStrSet, name, key);
                }
                break;
            case REMOVE:
                for (String k : values.keySet()) {
                    key = k;
                    if (keyNotEmpty = !TextUtils.isEmpty(key)) {
                        valueChanged = true;
                        editor.remove(key);
                    }
                    break;
                }
                if (keyNotEmpty) {
                    endPut(editor, commitOrApply);
                    if (valueChanged) uri4Notify = makeNotifyUri(sRemove, name, key);
                }
                break;
            case CLEAR:
                valueChanged = keyNotEmpty = true;
                editor.clear();
                endPut(editor, commitOrApply);
                uri4Notify = makeNotifyUri(sClear, name, sClearKey4Notify);
                break;
            default:
                throw newException4UnsupportedOperation();
        }
        if (valueChanged) getContext().getContentResolver().notifyChange(uri4Notify, null);
        return keyNotEmpty ? 1 : 0;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        throw newException4UnsupportedOperation();
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        throw newException4UnsupportedOperation();
    }

    private void endPut(Editor editor, String action) {
        if (action.equalsIgnoreCase(APPLY)) {
            editor.apply();
        } else {
            editor.commit();
        }
    }

    private static int getNotEqualWith(int result, int notEqual) {
        return result == notEqual ? ++result : result;
    }

    private static float getNotEqualWith(Float result, Float notEqual) {
        return equals(result, notEqual) ? ++result : result;
    }

    private static long getNotEqualWith(long result, long notEqual) {
        return result == notEqual ? ++result : result;
    }

    private static boolean getNotEqualWith(boolean result, boolean notEqual) {
        return !notEqual;
    }

    private static String getNotEqualWith(String result, String notEqual) {
        return equals(result, notEqual) ? result == null ? "" : null : result;
    }

    private static Set<String> getNotEqualWith(Set<String> result, Set<String> notEqual) {
        return equals(result, notEqual) ? result == null ? Collections.<String>emptySet() : null : result;
    }

    /**
     * 摘自{@link Objects#equals(Object, Object)}, 因为其只支持API Level19+
     */
    public static boolean equals(Object a, Object b) {
        return (a == null) ? (b == null) : a.equals(b);
    }

    private void checkPermission() {
        if (Binder.getCallingUid() != getContext().getApplicationInfo().uid) {
            throw new SecurityException("非法用户");
        }
    }

    private static RuntimeException newException4NullName() {
        return new IllegalArgumentException("name不能为空");
    }

    private static RuntimeException newException4IllegalUri() {
        return new IllegalArgumentException("错误的Uri");
    }

    private static RuntimeException newException4UnsupportedOperation() {
        return new UnsupportedOperationException("不支持的操作");
    }
}
