import localUnitTest from './LocalUnit.test';
import syncMergeCoreTest from './SyncMergeCore.test';

export default function testsuite() {
  localUnitTest();
  syncMergeCoreTest();
}
