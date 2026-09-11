import { describe, it, expect } from '@ohos/hypium';
import { lwwScore, pickWinner, mergeDayRecords } from '../../main/ets/services/SyncMergeCore';
import { GoodDeedRecord, RecordType, SyncStatus } from '../../main/ets/model/Types';

/** 构造测试记录 */
function makeRecord(id: string, dayKey: string, updatedAt: string,
  syncVersion?: number, status?: SyncStatus): GoodDeedRecord {
  const r: GoodDeedRecord = {
    id: id,
    type: 'text',
    content: '内容-' + id,
    media: [],
    dayKey: dayKey,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    status: status || 'synced'
  };
  if (syncVersion !== undefined) {
    r.syncVersion = syncVersion;
  }
  return r;
}

export default function syncMergeCoreTest() {
  describe('syncMergeCore', () => {
    it('lwwScore_prefersSyncVersion', 0, () => {
      const r = makeRecord('a', '2026-09-11', '2020-01-01T00:00:00.000Z', 7);
      expect(lwwScore(r)).assertEqual(7);
    });

    it('lwwScore_fallsBackToTime', 0, () => {
      const r = makeRecord('a', '2026-09-11', '2026-01-02T00:00:00.000Z');
      expect(lwwScore(r)).assertEqual(Date.parse('2026-01-02T00:00:00.000Z'));
    });

    it('pickWinner_localNewer', 0, () => {
      const local = makeRecord('a', '2026-09-11', '2026-01-01T00:00:00.000Z', 2);
      const remote = makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1);
      expect(pickWinner(local, remote)).assertEqual('local');
    });

    it('pickWinner_remoteNewer', 0, () => {
      const local = makeRecord('a', '2026-09-11', '2026-01-01T00:00:00.000Z', 1);
      const remote = makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 3);
      expect(pickWinner(local, remote)).assertEqual('remote');
    });

    it('pickWinner_equal', 0, () => {
      const local = makeRecord('a', '2026-09-11', '2026-01-01T00:00:00.000Z', 1);
      const remote = makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1);
      expect(pickWinner(local, remote)).assertEqual('equal');
    });

    it('merge_remoteOnly_appearsNotPushed', 0, () => {
      const local: GoodDeedRecord[] = [];
      const remote: GoodDeedRecord[] = [makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1)];
      const result = mergeDayRecords(local, remote);
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('srv-1');
      expect(result.toPushIds.length).assertEqual(0);
    });

    it('merge_localOnly_keptAndPushed', 0, () => {
      const local: GoodDeedRecord[] = [makeRecord('local-1', '2026-09-11', '2026-01-01T00:00:00.000Z')];
      const remote: GoodDeedRecord[] = [];
      const result = mergeDayRecords(local, remote);
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('local-1');
      expect(result.toPushIds.length).assertEqual(1);
      expect(result.toPushIds[0]).assertEqual('local-1');
    });

    it('merge_localNewer_keptAndPushed', 0, () => {
      const local: GoodDeedRecord[] = [makeRecord('local-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 2)];
      const remote: GoodDeedRecord[] = [makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1)];
      const result = mergeDayRecords(local, remote);
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('local-1');
      expect(result.toPushIds.length).assertEqual(1);
    });

    it('merge_remoteNewer_overwritesLocal', 0, () => {
      const local: GoodDeedRecord[] = [makeRecord('local-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1)];
      const remote: GoodDeedRecord[] = [makeRecord('srv-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 2)];
      const result = mergeDayRecords(local, remote);
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('srv-1');
      expect(result.toPushIds.length).assertEqual(0);
    });

    it('merge_localInFlight_notOverwritten', 0, () => {
      const local: GoodDeedRecord[] =
        [makeRecord('local-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1, 'uploading')];
      const remote: GoodDeedRecord[] = [makeRecord('srv-1', '2026-09-11', '2020-01-01T00:00:00.000Z', 5)];
      const result = mergeDayRecords(local, remote);
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('local-1');
      expect(result.merged[0].status).assertEqual('uploading');
    });

    it('merge_matchedByServerRecordId', 0, () => {
      const l = makeRecord('local-1', '2026-09-11', '2026-01-01T00:00:00.000Z', 1);
      l.serverRecordId = '42';
      const local: GoodDeedRecord[] = [l];
      const remote: GoodDeedRecord[] = [makeRecord('srv-42', '2026-09-11', '2026-01-01T00:00:00.000Z', 1)];
      const result = mergeDayRecords(local, remote);
      // 两端相等 → 保留本地
      expect(result.merged.length).assertEqual(1);
      expect(result.merged[0].id).assertEqual('local-1');
      expect(result.toPushIds.length).assertEqual(0);
    });
  });
}
