import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * KvStore — preferences 同步封装（local-first 底座）
 * EntryAbility.onCreate 时调用 init(context)，其余服务同步读写。
 */
export class KvStore {
  private static prefs: preferences.Preferences | null = null;

  static init(context: common.Context): void {
    KvStore.prefs = preferences.getPreferencesSync(context, { name: 'rxys_kv' });
  }

  private static pref(): preferences.Preferences {
    if (KvStore.prefs === null) {
      throw new Error('KvStore 未初始化，请先在 EntryAbility 调用 KvStore.init(context)');
    }
    return KvStore.prefs;
  }

  static getString(key: string): string {
    const v = KvStore.pref().getSync(key, '');
    return v as string;
  }

  static setString(key: string, value: string): void {
    KvStore.pref().putSync(key, value);
    KvStore.flush();
  }

  static remove(key: string): void {
    KvStore.pref().deleteSync(key);
    KvStore.flush();
  }

  /** 读取 JSON 值，解析失败时返回 fallback */
  static getJson<T extends object>(key: string, fallback: T): T {
    const raw = KvStore.getString(key);
    if (!raw) {
      return fallback;
    }
    try {
      return JSON.parse(raw) as T;
    } catch (e) {
      return fallback;
    }
  }

  static setJson(key: string, value: object): void {
    KvStore.setString(key, JSON.stringify(value));
  }

  /** 异步落盘，失败静默（下一次 put 仍会尝试 flush） */
  private static flush(): void {
    if (KvStore.prefs !== null) {
      KvStore.prefs.flush().catch(() => {});
    }
  }
}
