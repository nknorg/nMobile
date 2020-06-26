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
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.database.ContentObserver;
import android.database.Cursor;
import android.database.Observable;
import android.net.Uri;
import android.os.Handler;
import android.util.Log;

import java.lang.ref.WeakReference;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import hobby.wei.c.tool.LruCache;

/**
 * @author Wei Chou(weichou2010@gmail.com)
 * @version 0.1, 02/09/2015;
 * 1.0, 27/07/2018，增加监听以清除缓存。
 */
public class MultiProcesSharedPreferences implements SharedPreferences {
    private static final String TAG = "MultiProcesSharedPrefer";

    private static final Map<String, WeakReference<MultiProcesSharedPreferences>> sName2MpspMap = new HashMap<>();
    private final MyObservable mObservable = new MyObservable();
    private final ContentObserver mContentObserver;
    private final Context mContext;
    private final String mName;
    private final Cache mCache;

    public static MultiProcesSharedPreferences getInstance(Context context, String name) {
        final String nameLC = name.toLowerCase();
        WeakReference<MultiProcesSharedPreferences> ref = sName2MpspMap.get(nameLC);
        MultiProcesSharedPreferences mpsp = ref == null ? null : ref.get();
        if (mpsp == null) {
            Log.d(TAG, "[getInstance]hit = false, name: " + name + ".");
            synchronized (MultiProcesSharedPreferences.class) {
                ref = sName2MpspMap.get(nameLC);
                mpsp = ref == null ? null : ref.get();
                if (mpsp == null) {
                    mpsp = new MultiProcesSharedPreferences(context, name);
                    sName2MpspMap.put(nameLC, new WeakReference<>(mpsp));
                }
            }
        }
        return mpsp;
    }

    private MultiProcesSharedPreferences(Context context, String name) {
        mContext = context.getApplicationContext();
        mName = name;
        mContentObserver = new MyContentObserver(this, null);
        mCache = new Cache();
        // 解决[在多进程中]当某进程对某key更新时，其它进程由于`mCache`而无法获得更新的问题。
        registerOnSharedPreferenceChangeListener(new OnSharedPreferenceChangeListener() {
            @Override
            public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
                Log.d(TAG, "[onShrdPrfrceChge]key: " + key + ".");
                mCache.remove(key);
            }
        });
    }

    @Override
    public int getInt(String key, int defValue) {
        final Integer value = mCache.getInt(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetInt(mName),
                new String[]{key}, null, new String[]{Integer.toString(defValue)}, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return cursor.getInt(0);
                }
            } finally {
                cursor.close();
            }
        }
        return defValue;
    }

    @Override
    public float getFloat(String key, float defValue) {
        final Float value = mCache.getFloat(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetFloat(mName),
                new String[]{key}, null, new String[]{Float.toString(defValue)}, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return cursor.getFloat(0);
                }
            } finally {
                cursor.close();
            }
        }
        return defValue;
    }

    @Override
    public long getLong(String key, long defValue) {
        final Long value = mCache.getLong(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetLong(mName),
                new String[]{key}, null, new String[]{Long.toString(defValue)}, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return cursor.getLong(0);
                }
            } finally {
                cursor.close();
            }
        }
        return defValue;
    }

    @Override
    public boolean getBoolean(String key, boolean defValue) {
        final Boolean value = mCache.getBoolean(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetBoolean(mName),
                new String[]{key}, null, new String[]{Boolean.toString(defValue)}, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return parseBoolean(cursor.getBlob(0));
                }
            } finally {
                cursor.close();
            }
        }
        return defValue;
    }

    @Override
    public String getString(String key, String defValue) {
        final String value = mCache.getString(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetString(mName),
                new String[]{key}, null, new String[]{defValue}, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return cursor.getString(0);
                }
            } finally {
                cursor.close();
            }
        }
        return defValue;
    }

    @Override
    public Set<String> getStringSet(String key, Set<String> defValues) {
        final Set<String> value = mCache.getStringSet(key);
        if (value != null) return value;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetStringSet(mName),
                new String[]{key}, null, null, null);
        if (cursor != null) {
            try {
                final Set<String> set = new HashSet<String>();
                while (cursor.moveToNext()) {
                    Log.i(TAG, "[getStringSet]string: " + cursor.getString(0) + ".");
                    set.add(cursor.getString(0));
                }
                return set;
            } finally {
                cursor.close();
            }
        }
        return defValues;
    }

    @SuppressLint("NewApi")
    @Override
    public Map<String, ?> getAll() {
        final Map<String, Object> map = new HashMap<String, Object>();
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetAll(mName), null, null, null, null);
        if (cursor != null) {
            try {
                while (cursor.moveToNext()) {
                    final String key = cursor.getString(0);
                    switch (cursor.getType(1)) {
                        case Cursor.FIELD_TYPE_NULL:
                            Log.i(TAG, String.format("[getAll]FIELD_TYPE_NULL: %s", (Object) null));
                            map.put(key, null);
                            break;
                        case Cursor.FIELD_TYPE_INTEGER:
                            Log.i(TAG, String.format("[getAll]FIELD_TYPE_INTEGER: %s", cursor.getInt(1)));
                            map.put(key, cursor.getInt(1));
                            break;
                        case Cursor.FIELD_TYPE_FLOAT:
                            Log.i(TAG, String.format("[getAll]FIELD_TYPE_FLOAT: %s", cursor.getFloat(1)));
                            map.put(key, cursor.getFloat(1));
                            break;
                        case Cursor.FIELD_TYPE_STRING:
                            Log.i(TAG, String.format("[getAll]FIELD_TYPE_STRING: %s", cursor.getString(1)));
                            map.put(key, cursor.getString(1));
                            break;
                        case Cursor.FIELD_TYPE_BLOB:
                            Log.i(TAG, String.format("[getAll]FIELD_TYPE_BLOB: %s", (Object) cursor.getBlob(1)));
                            final byte[] blob = cursor.getBlob(1);
                            if (blob.length == 1) {    //用来表示boolean
                                map.put(key, parseBoolean(blob));
                                Log.i(TAG, String.format("[getAll]FIELD_TYPE_BLOB, boolean: %s", map.get(key)));
                            } else {    //用来表示StringSet类型
                                if (Arrays.equals(blob, SharedPreferencesProvider.FLAG_STRING_SET)) {
                                    map.put(key, getStringSet(key, new HashSet<String>())); //defValue一个没元素的对象至少可以表示类型
                                    Log.i(TAG, String.format("[getAll]FIELD_TYPE_BLOB, stringSet: %s", map.get(key)));
                                }
                            }
                            break;
                        default:
                            break;
                    }
                }
            } finally {
                cursor.close();
            }
        }
        return map;
    }

    @Override
    public boolean contains(String key) {
        if (mCache.contains(key)) return true;
        final Cursor cursor = mContext.getContentResolver().query(SharedPreferencesProvider.getUri4GetContains(mName),
                new String[]{key}, null, null, null);
        if (cursor != null) {
            try {
                if (cursor.moveToNext()) {
                    return parseBoolean(cursor.getBlob(0));
                }
            } finally {
                cursor.close();
            }
        }
        return false;
    }

    @Override
    public void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        mObservable.registerObserver(listener);
        if (mObservable.countObservers() == 1) {
            mContext.getContentResolver().registerContentObserver(
                    SharedPreferencesProvider.getUri4NotifyObserver(mName), true, mContentObserver);
            Log.i(TAG, String.format("[regstOnShrdPrfrceChgeLiser]Uri4NotifyObserver: %s", SharedPreferencesProvider.getUri4NotifyObserver(mName)));
        }
    }

    @Override
    public void unregisterOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        mObservable.unregisterObserver(listener);
        if (mObservable.countObservers() <= 0) {
            mContext.getContentResolver().unregisterContentObserver(mContentObserver);
            Log.i(TAG, "[unregisterContentObserver]");
        }
    }

    @Override
    public Editor edit() {
        return new MyEditor(this);
    }

    public static class MyEditor implements Editor {
        private final MultiProcesSharedPreferences mSPref;
        private Map<String, Integer> mS2IMap;
        private Map<String, Float> mS2FMap;
        private Map<String, Long> mS2LMap;
        private Map<String, Boolean> mS2BMap;
        private Map<String, String> mS2SMap;
        private Map<String, Set<String>> mS2EMap;
        private Set<String> mRmvSet;
        private boolean mClearFlag;

        private MyEditor(MultiProcesSharedPreferences spref) {
            mSPref = spref;
        }

        @Override
        public Editor putInt(String key, int value) {
            checkEmpty(key);
            if (mS2IMap == null) mS2IMap = new HashMap<>();
            mS2IMap.put(key, value);
            return this;
        }

        @Override
        public Editor putFloat(String key, float value) {
            checkEmpty(key);
            if (mS2FMap == null) mS2FMap = new HashMap<>();
            mS2FMap.put(key, value);
            return this;
        }

        @Override
        public Editor putLong(String key, long value) {
            checkEmpty(key);
            if (mS2LMap == null) mS2LMap = new HashMap<>();
            mS2LMap.put(key, value);
            return this;
        }

        @Override
        public Editor putBoolean(String key, boolean value) {
            checkEmpty(key);
            if (mS2BMap == null) mS2BMap = new HashMap<>();
            mS2BMap.put(key, value);
            return this;
        }

        @Override
        public Editor putString(String key, String value) {
            checkEmpty(key);
            checkEmpty(value);
            if (mS2SMap == null) mS2SMap = new HashMap<>();
            mS2SMap.put(key, value);
            return this;
        }

        @Override
        public Editor putStringSet(String key, Set<String> values) {
            checkEmpty(key);
            checkEmpty(values);
            if (values.isEmpty()) {
                remove(key);
            } else {
                if (mS2EMap == null) mS2EMap = new HashMap<>();
                mS2EMap.put(key, values);
            }
            return this;
        }

        @Override
        public Editor remove(String key) {
            checkEmpty(key);
            if (mRmvSet == null) mRmvSet = new HashSet<>();
            mRmvSet.add(key);
            if (mS2IMap != null) mS2IMap.remove(key);
            if (mS2FMap != null) mS2FMap.remove(key);
            if (mS2LMap != null) mS2LMap.remove(key);
            if (mS2BMap != null) mS2BMap.remove(key);
            if (mS2SMap != null) mS2SMap.remove(key);
            if (mS2EMap != null) mS2EMap.remove(key);
            return this;
        }

        @Override
        public Editor clear() {
            mClearFlag = true;
            if (mS2IMap != null) mS2IMap.clear();
            if (mS2FMap != null) mS2FMap.clear();
            if (mS2LMap != null) mS2LMap.clear();
            if (mS2BMap != null) mS2BMap.clear();
            if (mS2SMap != null) mS2SMap.clear();
            if (mS2EMap != null) mS2EMap.clear();
            if (mRmvSet != null) mRmvSet.clear();
            return this;
        }

        @Override
        public boolean commit() {
            final boolean bclear = sendClearOrRemove(true);
            final boolean bint = sendInts(true);
            final boolean bfloat = sendFloats(true);
            final boolean blong = sendLongs(true);
            final boolean bbool = sendBooleans(true);
            final boolean bstring = sendStrings(true);
            final boolean bstrset = sendStringSets(true);
            Log.d(mSPref.TAG, String.format("[commit]success: %s", bclear && bint && bfloat && blong && bbool && bstring && bstrset));
            return bclear && bint && bfloat && blong && bbool && bstring && bstrset;
        }

        @Override
        public void apply() {
            sendClearOrRemove(false);
            sendInts(false);
            sendFloats(false);
            sendLongs(false);
            sendBooleans(false);
            sendStrings(false);
            sendStringSets(false);
        }

        private boolean sendClearOrRemove(boolean commit) {
            boolean success = true;
            final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
            final ContentValues contentValues = new ContentValues();
            if (mClearFlag) {
                mSPref.mCache.clear();
                final Uri uri = SharedPreferencesProvider.getUri4Clear(mSPref.mName);
                success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                        SharedPreferencesProvider.APPLY, null);
                Log.d(mSPref.TAG, String.format("[sendClearOrRemove]CLEAR, success: %s", success));
            } else if (mRmvSet != null) {
                final Uri uri = SharedPreferencesProvider.getUri4Remove(mSPref.mName);
                for (String key : mRmvSet) {
                    mSPref.mCache.remove(key);
                    contentValues.clear();
                    contentValues.put(key, (String) null);
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendClearOrRemove]REMOVE, success: %s", success));
                }
            }
            return success;
        }

        private boolean sendInts(boolean commit) {
            //没有待发送的也应该返回成功
            boolean success = true;
            if (mS2IMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutInt(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, Integer> entry : mS2IMap.entrySet()) {
                    contentValues.clear();
                    contentValues.put(entry.getKey(), entry.getValue());
                    //不要if(), 否则后面的update不执行。
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendInts]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putInt(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }

        private boolean sendFloats(boolean commit) {
            boolean success = true;
            if (mS2FMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutFloat(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, Float> entry : mS2FMap.entrySet()) {
                    contentValues.clear();
                    contentValues.put(entry.getKey(), entry.getValue());
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendFloats]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putFloat(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }

        private boolean sendLongs(boolean commit) {
            boolean success = true;
            if (mS2LMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutLong(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, Long> entry : mS2LMap.entrySet()) {
                    contentValues.clear();
                    contentValues.put(entry.getKey(), entry.getValue());
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendLongs]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putLong(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }

        private boolean sendBooleans(boolean commit) {
            boolean success = true;
            if (mS2BMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutBoolean(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, Boolean> entry : mS2BMap.entrySet()) {
                    contentValues.clear();
                    contentValues.put(entry.getKey(), entry.getValue());
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendBooleans]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putBoolean(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }

        private boolean sendStrings(boolean commit) {
            boolean success = true;
            if (mS2SMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutString(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, String> entry : mS2SMap.entrySet()) {
                    contentValues.clear();
                    contentValues.put(entry.getKey(), entry.getValue());
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendStrings]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putString(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }

        private boolean sendStringSets(boolean commit) {
            boolean success = true;
            if (mS2EMap != null) {
                final ContentResolver contentResolver = mSPref.mContext.getContentResolver();
                final Uri uri = SharedPreferencesProvider.getUri4PutStringSet(mSPref.mName);
                final ContentValues contentValues = new ContentValues();
                for (Map.Entry<String, Set<String>> entry : mS2EMap.entrySet()) {
                    contentValues.clear();
                    final String key = entry.getKey();
                    int count = 0;
                    for (String value : entry.getValue()) {
                        contentValues.put(key + (count++ == 0 ? "" : count), value);
                    }
                    success &= 0 < contentResolver.update(uri, contentValues, commit ? SharedPreferencesProvider.COMMIT :
                            SharedPreferencesProvider.APPLY, null);
                    Log.d(mSPref.TAG, String.format("[sendStringSets]success: %s, key: %s.", success, entry.getKey()));
                    // 放到最后。由于在初始化时注册了监听，会清除对应key的缓存，若放在前面，事实上无效。
                    mSPref.mCache.putStringSet(entry.getKey(), entry.getValue());
                }
            }
            return success;
        }
    }

    private static class Cache implements Editor {
        private LruCache<String, Integer> mS2IMap;
        private LruCache<String, Float> mS2FMap;
        private LruCache<String, Long> mS2LMap;
        private LruCache<String, Boolean> mS2BMap;
        private LruCache<String, String> mS2SMap;
        private LruCache<String, Set<String>> mS2EMap;

        @Override
        public Editor putInt(String key, int value) {
            if (mS2IMap == null) mS2IMap = new LruCache<>(5);
            mS2IMap.put(key, value);
            return this;
        }

        @Override
        public Editor putFloat(String key, float value) {
            if (mS2FMap == null) mS2FMap = new LruCache<>(5);
            mS2FMap.put(key, value);
            return this;
        }

        @Override
        public Editor putLong(String key, long value) {
            if (mS2LMap == null) mS2LMap = new LruCache<>(5);
            mS2LMap.put(key, value);
            return this;
        }

        @Override
        public Editor putBoolean(String key, boolean value) {
            if (mS2BMap == null) mS2BMap = new LruCache<>(5);
            mS2BMap.put(key, value);
            return this;
        }

        @Override
        public Editor putString(String key, String value) {
            Log.d(TAG, String.format("[Cache.putString]key: %s, value: %s", key, value));
            if (mS2SMap == null) mS2SMap = new LruCache<>(5);
            mS2SMap.put(key, value);
            return this;
        }

        @Override
        public Editor putStringSet(String key, Set<String> values) {
            if (values.isEmpty()) remove(key);
            else {
                if (mS2EMap == null) mS2EMap = new LruCache<>(5);
                mS2EMap.put(key, values);
            }
            return this;
        }

        @Override
        public Editor remove(String key) {
            checkEmpty(key);
            if (mS2IMap != null) mS2IMap.remove(key);
            if (mS2FMap != null) mS2FMap.remove(key);
            if (mS2LMap != null) mS2LMap.remove(key);
            if (mS2BMap != null) mS2BMap.remove(key);
            if (mS2SMap != null) mS2SMap.remove(key);
            if (mS2EMap != null) mS2EMap.remove(key);
            return this;
        }

        @Override
        public Editor clear() {
            if (mS2IMap != null) mS2IMap.evictAll();
            if (mS2FMap != null) mS2FMap.evictAll();
            if (mS2LMap != null) mS2LMap.evictAll();
            if (mS2BMap != null) mS2BMap.evictAll();
            if (mS2SMap != null) mS2SMap.evictAll();
            if (mS2EMap != null) mS2EMap.evictAll();
            return this;
        }

        @Override
        public boolean commit() {
            return false;
        }

        @Override
        public void apply() {
        }

        public Integer getInt(String key) {
            return mS2IMap == null ? null : mS2IMap.get(key);
        }

        public Float getFloat(String key) {
            return mS2FMap == null ? null : mS2FMap.get(key);
        }

        public Long getLong(String key) {
            return mS2LMap == null ? null : mS2LMap.get(key);
        }

        public Boolean getBoolean(String key) {
            return mS2BMap == null ? null : mS2BMap.get(key);
        }

        public String getString(String key) {
            return mS2SMap == null ? null : mS2SMap.get(key);
        }

        public Set<String> getStringSet(String key) {
            return mS2EMap == null ? null : mS2EMap.get(key);
        }

        public boolean contains(String key) {
            return (mS2IMap != null && mS2IMap.snapshot().containsKey(key))
                    || (mS2FMap != null && mS2FMap.snapshot().containsKey(key))
                    || (mS2LMap != null && mS2LMap.snapshot().containsKey(key))
                    || (mS2BMap != null && mS2BMap.snapshot().containsKey(key))
                    || (mS2SMap != null && mS2SMap.snapshot().containsKey(key))
                    || (mS2EMap != null && mS2EMap.snapshot().containsKey(key));
        }
    }

    private static class MyObservable extends Observable<OnSharedPreferenceChangeListener> {
        public int countObservers() {
            return mObservers.size();
        }

        public void notifyChanged(SharedPreferences spref, String key) {
            // 必须先通知第一个（初始化的时候注册的），以便清除缓存。
            mObservers.get(0).onSharedPreferenceChanged(spref, key);
            synchronized (mObservers) {
                for (int i = mObservers.size() - 1; i >/*=*/ 0; i--) {
                    mObservers.get(i).onSharedPreferenceChanged(spref, key);
                }
            }
        }
    }

    private static class MyContentObserver extends ContentObserver {
        private final WeakReference<MultiProcesSharedPreferences> mSPrefRef;

        MyContentObserver(MultiProcesSharedPreferences spref, Handler handler) {
            super(handler);
            mSPrefRef = new WeakReference<>(spref);
        }

        public void onChange(boolean selfChange, Uri uri) {
            Log.d(TAG, String.format("[onChange]selfChange: %s, uri: %s", selfChange, uri));
            final String[] name$key = SharedPreferencesProvider.parseNotifyNameAndKey(uri);
            Log.d(TAG, String.format("[onChange]name: %s, key: %s", name$key[0], name$key[1]));
            final MultiProcesSharedPreferences spref = mSPrefRef.get();
            if (spref != null) {
                final String key = name$key[1];
                if (key != null) {  //SharedPreferencesProvider.NOTIFY_CLEAR类型没有key
                    spref.mObservable.notifyChanged(spref, key);
                }
            }
        }
    }

    private static boolean parseBoolean(byte[] blob) {
        return Arrays.equals(blob, SharedPreferencesProvider.FLAG_BOOL_TRUE);
    }

    private static void checkEmpty(Object obj) {
        if (obj == null || obj instanceof CharSequence && ((CharSequence) obj).length() == 0)
            throw new IllegalArgumentException("parameter should not be null");
    }
}
