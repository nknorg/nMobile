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

import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;

import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import static hobby.wei.c.util.Assist.requireNonEmpty;
import static hobby.wei.c.util.Assist.requireNotNull;

/**
 * @author Wei Chou(weichou2010@gmail.com)
 * @version 1.0, 02/12/2015;
 * 1.1, 04/01/2017, 增加withUser().
 */
public class Storer {
    protected static final String STORER_NAME_DEF = "storer_db";
    private static final Map<String, WeakReference<Storer>> sName2StorerMap = new HashMap<>();

    private static Storer get(Context context, String storerName, boolean multiProcess) {
        final String storerNameLC = requireNonEmpty(storerName).toLowerCase();
        WeakReference<Storer> ref = sName2StorerMap.get(storerNameLC);
        Storer instance = ref == null ? null : ref.get();
        if (instance == null) {
            synchronized (Storer.class) {
                ref = sName2StorerMap.get(storerNameLC);
                instance = ref == null ? null : ref.get();
                if (instance == null) {
                    instance = new Storer(context, storerName, multiProcess);
                    sName2StorerMap.put(storerNameLC, new WeakReference<>(instance));
                }
            }
        }
        return instance;
    }

    private final String mStorerName;
    private final SharedPreferences mSPref;

    private Storer(Context context, String storerName, boolean multiProcess) {
        mStorerName = storerName;
        mSPref = multiProcess ? SPrefHelper.multiProcess().getSPref(context, mStorerName) :
                SPrefHelper.def().getSPref(context, mStorerName);
    }

    public String getStorerName() {
        return mStorerName;
    }

    public SharedPreferences getSharedPreferences() {
        return mSPref;
    }

    public Editor edit() {
        return mSPref.edit();
    }

    public static Builder.User get(Context context, String storerName) {
        return new Builder.User(context, storerName);
    }

    /**
     * 用法示例：
     * <pre><code>
     * public class XxxStorer extends Storer.Wrapper {
     *      private static final String STORER_NAME = "xxx-state";
     *
     *      public static XxxStorer get(String userId) {
     *          return Storer.get(AbsApp.get().getApplicationContext(), STORER_NAME).withUser(userId).bind(new XxxStorer());
     *      }
     *
     *      public saveXxx(String key, String value) {
     *          get.storeString(key, value);
     *      }
     * }
     * </code></pre>
     */
    public static class Wrapper {
        public static Builder.User get(Context context, String storerName) {
            return Storer.get(context, storerName);
        }

        private Storer mStorer;

        protected Wrapper() {
        }

        <T extends Wrapper> T bind(Storer storer) {
            mStorer = storer;
            return (T) this;
        }

        public Storer get() {
            return requireNotNull(mStorer, "请确保之前调用了Storer.get(Context, String).bind(Wrapper)而不是ok()");
        }
    }

    public static class Builder {
        private final Context mContext;
        String mStorerName;
        boolean mMultiProcess = false;

        private Builder(Context context, String storerName) {
            mContext = requireNotNull(context);
            mStorerName = requireNonEmpty(storerName);
        }

        public Storer ok() {
            return get(mContext, mStorerName, mMultiProcess);
        }

        public <T extends Wrapper> T bind(T wrapper) {
            return wrapper.bind(ok());
        }

        public static class Multiper extends Builder {
            private Multiper(Context context, String storerName) {
                super(context, storerName);
            }

            public Builder multiProcess() {
                mMultiProcess = true;
                return this;
            }
        }

        public static class Localer extends Multiper {
            private Localer(Context context, String storerName) {
                super(context, storerName);
            }

            /**
             * 获取根据地区语言不同而隔离的{@link Storer}实例。
             */
            // 返回{@link Builder}类型是为了避免再次出现本法。这里非常重要。
            public Multiper withLocale() {
                mStorerName += "-" + Locale.getDefault().toString();
                return this;
            }
        }

        public static class User extends Localer {
            User(Context context, String storerName) {
                super(context, storerName);
            }

            /**
             * 获取根据UserId不同而隔离的{@link Storer}实例。
             */
            // 返回{@link Localer}类型是为了避免再次出现本法。这里非常重要。
            public Localer withUser(String userId) {
                mStorerName += "-" + requireNotNull(userId);
                return this;
            }
        }
    }

    public Storer storeInt(String key, int value) {
        edit().putInt(requireNonEmpty(key), value).apply();
        return this;
    }

    public int loadInt(String key) {
        return loadInt(key, -1);
    }

    public int loadInt(String key, int defaultValue) {
        return mSPref.getInt(requireNonEmpty(key), defaultValue);
    }

    public Storer storeBoolean(String key, boolean value) {
        edit().putBoolean(requireNonEmpty(key), value).apply();
        return this;
    }

    public boolean loadBoolean(String key) {
        return loadBoolean(key, false);
    }

    public boolean loadBoolean(String key, boolean defaultValue) {
        return mSPref.getBoolean(requireNonEmpty(key), defaultValue);
    }

    public Storer storeFloat(String key, float value) {
        edit().putFloat(requireNonEmpty(key), value).apply();
        return this;
    }

    public float loadFloat(String key) {
        return loadFloat(key, -1);
    }

    public float loadFloat(String key, float defaultValue) {
        return mSPref.getFloat(requireNonEmpty(key), defaultValue);
    }

    public Storer storeLong(String key, long value) {
        edit().putLong(requireNonEmpty(key), value).apply();
        return this;
    }

    public long loadLong(String key) {
        return loadLong(key, -1);
    }

    public long loadLong(String key, long defaultValue) {
        return mSPref.getLong(requireNonEmpty(key), defaultValue);
    }

    public Storer storeString(String key, String value) {
        edit().putString(requireNonEmpty(key), value).apply();
        return this;
    }

    public String loadString(String key) {
        return loadString(key, null);
    }

    public String loadString(String key, String defaultValue) {
        return mSPref.getString(requireNonEmpty(key), defaultValue);
    }

    public Storer remove(String key) {
        edit().remove(requireNonEmpty(key)).apply();
        return this;
    }

    public boolean contains(String key) {
        return mSPref.contains(requireNonEmpty(key));
    }
}
