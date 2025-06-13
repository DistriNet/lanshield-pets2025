package org.distrinet.lanshield.database.dao

import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import org.distrinet.lanshield.Policy
import org.distrinet.lanshield.database.model.LanAccessPolicy

@Dao
interface LanAccessPolicyDao {

    @Query("SELECT accessPolicy FROM lan_access_policies WHERE packageName == :packageName")
    fun getPolicyByPackageName(packageName: String): LiveData<Policy?>

    @Query("SELECT * FROM lan_access_policies")
    fun getAllLive(): LiveData<List<LanAccessPolicy>>

    @Query("SELECT * FROM lan_access_policies WHERE isSystem = 0")
    fun getAllNoSystem(): LiveData<List<LanAccessPolicy>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertAll(vararg lanAccessPolicies: LanAccessPolicy)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(lanAccessPolicy: LanAccessPolicy)

    @Delete
    fun delete(lanAccessPolicy: LanAccessPolicy)

    @Query("DELETE FROM lan_access_policies")
    fun deleteAll()

    @Update
    suspend fun update(vararg lanAccessPolicy: LanAccessPolicy)

    @Query("SELECT COUNT(*) FROM lan_access_policies WHERE accessPolicy = :policy")
    fun countByPolicy(policy: Policy): LiveData<Int>

    @Query("UPDATE lan_access_policies SET accessPolicy = :newPolicy WHERE packageName = :packageName")
    fun updatePolicyByPackageName(packageName: String, newPolicy: Policy)
}
