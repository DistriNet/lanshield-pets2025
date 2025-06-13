package org.distrinet.lanshield.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import org.distrinet.lanshield.database.dao.FlowDao
import org.distrinet.lanshield.database.dao.LANShieldSessionDao
import org.distrinet.lanshield.database.dao.LanAccessPolicyDao
import org.distrinet.lanshield.database.model.LANFlow
import org.distrinet.lanshield.database.model.LANShieldSession
import org.distrinet.lanshield.database.model.LanAccessPolicy

@Database(entities = [LanAccessPolicy::class, LANFlow::class, LANShieldSession::class], version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun LanAccessPolicyDao(): LanAccessPolicyDao
    abstract fun FlowDao(): FlowDao
    abstract fun LANShieldSessionDao(): LANShieldSessionDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null
        fun getDatabase(context: Context): AppDatabase {
            val tempInstance = INSTANCE
            if (tempInstance != null) {
                return tempInstance
            }
            synchronized(this) {
                val instance = Room.databaseBuilder(
                    context,
                    AppDatabase::class.java,
                    "lanshield_database"
                ).build()
                INSTANCE = instance
                return instance
            }
        }
    }
}

