/**
 * One-time migration script to update existing users with new privacy fields
 * 
 * Run this once to:
 * 1. Add profileVisibility field (default: 'full' for existing users)
 * 2. Add usersIScanned and scannedByUsers arrays
 * 3. Add privacySelectedAt timestamp
 * 4. Remove deprecated visibleInDirectory field
 * 
 * Usage:
 *   firebase functions:shell
 *   migrateUsersToPrivacySystem()
 * 
 * OR manually run from Firebase Console using this code
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const migrateUsersToPrivacySystem = functions.https.onRequest(
  async (req, res) => {
    try {
      const db = admin.firestore();
      const usersRef = db.collection('users');
      const snapshot = await usersRef.get();

      if (snapshot.empty) {
        res.status(200).json({
          success: true,
          message: 'No users to migrate',
          migratedCount: 0,
        });
        return;
      }

      const batch = db.batch();
      let migratedCount = 0;

      snapshot.forEach((doc) => {
        const data = doc.data();
        
        // Only migrate if privacy fields don't exist
        if (!data.profileVisibility) {
          batch.update(doc.ref, {
            // Add new privacy fields
            profileVisibility: 'full', // Existing users default to full
            usersIScanned: [],
            scannedByUsers: [],
            privacySelectedAt: admin.firestore.FieldValue.serverTimestamp(),
            
            // Remove deprecated field
            visibleInDirectory: admin.firestore.FieldValue.delete(),
          });
          migratedCount++;
        }
      });

      if (migratedCount > 0) {
        await batch.commit();
      }

      res.status(200).json({
        success: true,
        message: `Successfully migrated ${migratedCount} users`,
        migratedCount,
        totalUsers: snapshot.size,
      });
    } catch (error: any) {
      console.error('Migration failed:', error);
      res.status(500).json({
        success: false,
        message: 'Migration failed',
        error: error.message,
      });
    }
  }
);

/**
 * Alternative: Manual migration code for Firebase Console
 * 
 * Copy and run this in Firebase Console:
 * 
 * const db = admin.firestore();
 * const users = await db.collection('users').get();
 * const batch = db.batch();
 * 
 * users.forEach(doc => {
 *   if (!doc.data().profileVisibility) {
 *     batch.update(doc.ref, {
 *       profileVisibility: 'full',
 *       usersIScanned: [],
 *       scannedByUsers: [],
 *       privacySelectedAt: admin.firestore.FieldValue.serverTimestamp(),
 *       visibleInDirectory: admin.firestore.FieldValue.delete()
 *     });
 *   }
 * });
 * 
 * await batch.commit();
 * console.log('Migration complete!');
 */
