/*
 * Copyright (C) 2016-present, Wei Chou(weichou2010@gmail.com)
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

package hobby.wei.c.util;

import static android.text.TextUtils.isEmpty;

/**
 * @author Wei Chou(weichou2010@gmail.com)
 * @version 1.0, 02/07/2016
 */
public class Assist {
    private static final boolean DEBUG = false;

    public static void assertf(boolean b) {
        assertf(b, null, true);
    }

    public static void assertf(boolean b, String msg) {
        assertf(b, msg, true);
    }

    private static void assertf(boolean b, String msg, boolean force) {
        if ((force || DEBUG) && !b) throw new AssertionError(msg);
    }

    public static <T> T requireNonNull(T o) {
        assertf(o != null);
        return o;
    }

    public static <T> T requireEquals(T value, Object o) {
        assertf(value.equals(o));
        return value;
    }

    public static <T> T requireNonEquals(T value, Object o) {
        assertf(!value.equals(o));
        return value;
    }

    public static String requireNonEmpty(final String s) {
        assertf(!isEmpty(s));
        return s;
    }

    public static <T> T requireNotNull(T value) {
        return requireNotNull(value, null);
    }

    public static <T> T requireNotNull(T value, String msg) {
        assertf(value != null, msg);
        return value;
    }
}
