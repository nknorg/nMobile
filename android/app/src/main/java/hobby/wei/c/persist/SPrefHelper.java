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

import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;

/**
 * @author Wei Chou(weichou2010@gmail.com) 2015/9
 */
public class SPrefHelper {
    private static final SPrefHelper sSPrefHelper = new SPrefHelper();
    private static final SPrefHelper sMultiProcess = new MultiProcess();
    private final List<SharedPreferences> mSpRef = new LinkedList<SharedPreferences>();
    private final Map<String, SharedPreferences> mSpMap = new HashMap<String, SharedPreferences>();

    private SPrefHelper() {
    }

    public static SPrefHelper def() {
        return sSPrefHelper;
    }

    public static SPrefHelper multiProcess() {
        return sMultiProcess;
    }

    public SharedPreferences getSPref(Context context, String fileName) {
        return getSPrefInner(context, replace$(fileName));
    }

    public SharedPreferences getSPref(Context context, Object o) {
        return getSPref(context, fileName(o));
    }

    public SharedPreferences getSPref(Context context, Class<?> c) {
        return getSPref(context, fileName(c));
    }

    public SharedPreferences.Editor edit(Context context, String fileName) {
        return getSPref(context, fileName).edit();
    }

    public SharedPreferences.Editor edit(Context context, Object o) {
        return edit(context, fileName(o));
    }

    public SharedPreferences.Editor edit(Context context, Class<?> c) {
        return edit(context, fileName(c));
    }

    public void registerListener(Context context, String fileName, SharedPreferences.OnSharedPreferenceChangeListener l) {
        fileName = replace$(fileName);
        final String key = fileName.toLowerCase(Locale.US);
        SharedPreferences sp;
        synchronized (this) {
            sp = mSpMap.get(key);
            if (sp == null) {
                sp = getSPrefInner(context, fileName);
                mSpMap.put(key, sp);
            } else {
                mSpRef.add(sp);
            }
        }
        sp.registerOnSharedPreferenceChangeListener(l);
    }

    public void registerListener(Context context, Object o, SharedPreferences.OnSharedPreferenceChangeListener l) {
        registerListener(context, fileName(o), l);
    }

    public void registerListener(Context context, Class<?> c, SharedPreferences.OnSharedPreferenceChangeListener l) {
        registerListener(context, fileName(c), l);
    }

    public void unregisterListener(String fileName, SharedPreferences.OnSharedPreferenceChangeListener l) {
        fileName = replace$(fileName);
        final SharedPreferences sp;
        final String key = fileName.toLowerCase(Locale.US);
        synchronized (this) {
            if (!mSpRef.remove(sp = mSpMap.get(key))) {
                mSpMap.remove(key);
            }
        }
        sp.unregisterOnSharedPreferenceChangeListener(l);
    }

    public void unregisterListener(Object o, SharedPreferences.OnSharedPreferenceChangeListener l) {
        unregisterListener(fileName(o), l);
    }

    public void unregisterListener(Class<?> c, SharedPreferences.OnSharedPreferenceChangeListener l) {
        unregisterListener(fileName(c), l);
    }

    @TargetApi(Build.VERSION_CODES.HONEYCOMB)
    private static int getMode() {
        return Context.MODE_PRIVATE;    //Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB ? Context.MODE_MULTI_PROCESS : Context.MODE_PRIVATE;
    }

    private static String fileName(Object o) {
        if (o instanceof String) return (String) o;
        return fileName(o.getClass());
    }

    private static String fileName(Class<?> c) {
        return c.getName();
    }

    private static String replace$(String s) {
        return s.replaceAll("\\$", ".");    //不然会被解释为正则的的末尾字符，然后在末尾加上.字符
    }

    protected SharedPreferences getSPrefInner(Context context, String fileName) {
        return context.getSharedPreferences(fileName, getMode());
    }

    private static class MultiProcess extends SPrefHelper {
        private MultiProcess() {
        }

        @Override
        protected SharedPreferences getSPrefInner(Context context, String fileName) {
            return MultiProcesSharedPreferences.getInstance(context, fileName);
        }
    }
}
