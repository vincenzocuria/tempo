# WorkManager initializes its Room database before Flutter starts. Room creates
# WorkDatabase_Impl through reflection; R8 must retain its no-argument constructor.
# The previous APK failed with NoSuchMethodException: WorkDatabase_Impl.<init>().
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# WorkManager also instantiates this plugin worker reflectively.
-keep class com.chunkytofustudios.native_geofence.NativeGeofenceBackgroundWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}