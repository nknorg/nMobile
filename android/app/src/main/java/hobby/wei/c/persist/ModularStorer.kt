/*
* Copyright (C) 2017-present, Wei Chou(weichou2010@gmail.com)
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

package hobby.wei.c.persist

import hobby.wei.c.tool.LruCache
import org.nkn.mobile.app.App
import java.util.*
import kotlin.collections.HashSet

/**
 * @author Wei Chou(weichou2010@gmail.com)
 * @version 1.0, 27/10/2017
 */
abstract class ModularStorer : Storer.Wrapper() {

    @Suppress("UNCHECKED_CAST")
    companion object {
        private const val STORER_NAME = "storer-modular"
        private const val STORER_META = STORER_NAME + "_meta"
        private const val KEY_META = "meta"

        private val sCache = object : LruCache<Key<ModularStorer>, ModularStorer>(5) {
            override fun sizeOf(key: Key<ModularStorer>, value: ModularStorer) = 1

            override fun create(key: Key<ModularStorer>): ModularStorer {
                val module = if (key.clearable) key.module + "_c" else key.module
                ensureModule2Meta(key.userId, module, key.clearable)
                return key.creator(getModule(key.userId, module))
            }
        }

        private data class Key<out K : ModularStorer>(
            val userId: String,
            val module: String,
            val clearable: Boolean,
            val creator: (Storer.Builder) -> K
        ) {
            init {
                require(userId.isNotEmpty())
                require(module.isNotEmpty())
            }

            override fun equals(other: Any?) = if (other is Key<*> && other.canEqual(this)) {
                other.userId == this.userId && other.module == this.module && other.clearable == this.clearable
            } else false

            fun canEqual(that: Any) = that is Key<*>

            override fun hashCode() = 41 * (userId.hashCode() + (41 * (module.hashCode() + (if (clearable) 1 else 0))))
        }

        /**
         * 取得与参数指定的module关联的本对象。
         * <p>
         * 注意：虽然本对象里的方法可以在任何module被调用，但是请确保仅调用与参数module相关的方法，
         * 否则会造成混乱。因此，不建议将方法写在本类里面。
         * <p>
         * 不过也有在不同module下写同一个flag的需求，反正自己应该理清楚需求和存储关系。
         *
         * @param userId
         * @param module
         * @param clearable 是否可清除，以便在特定情况下（退出之后或登录之前）执行删除操作时。
         * @return
         */
        fun <K : ModularStorer> get(
            userId: String,
            module: String,
            clearable: Boolean,
            creator: (Storer.Builder) -> K
        ): K = sCache.get(Key(userId, module, clearable, creator)) as K

        private fun getModule(userId: String, module: String) = get(
            App.get().applicationContext,
            "$STORER_NAME-$module"
        ).withUser(userId).multiProcess()

        private fun ensureModule2Meta(userId: String, module: String, clearable: Boolean) {
            val meta: Storer = getMeta(userId)
            val set = meta.sharedPreferences.getStringSet(KEY_META, HashSet<String>() /*后面有add()操作*/)!!
            if (!set.contains(module)) {
                require(module != KEY_META)
                if (clearable) meta.edit().putBoolean(module, true).commit()
                set.add(module)
                meta.edit().putStringSet(KEY_META, set).commit()
            }
        }

        private fun getMeta(userId: String): Storer =
            get(App.get().applicationContext, STORER_META).withUser(userId).multiProcess().ok()

        fun clear(userId: String) {
            val meta: Storer = getMeta(userId)
            val set = meta.sharedPreferences.getStringSet(KEY_META, Collections.emptySet<String>())!!
            var b = false
            set.forEach { module ->
                if (meta.contains(module)) { // 是否有 clearable 标识，见上面的 meta.storeBoolean(module)。
                    if (!b) b = true
                    getModule(userId, module).ok().edit().clear().commit()
                    set.remove(module)
                }
            }
            if (b) meta.edit().putStringSet(KEY_META, set).commit()
        }

        fun clearNoUser(): Unit = clear(noUser.toString())
    }
}

object noUser {
    override fun toString() = "no_user"
}
