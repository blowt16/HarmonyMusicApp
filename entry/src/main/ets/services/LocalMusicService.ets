import fs from '@ohos.file.fs';
import media from '@ohos.multimedia.media';
import picker from '@ohos.file.picker';
import { common } from '@kit.AbilityKit';
import { Song } from '../models/MusicModel';
import { StorageService } from './StorageService';

const LOCAL_DIR_NAME: string = 'local_music';
const ALLOWED_EXTENSIONS: string[] = ['.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg'];

/**
 * 本地音乐导入：只复制用户通过系统文件选择器选中的音频到应用私有目录，
 * 不上传、不提交仓库，卸载应用后文件随之删除。
 */
export class LocalMusicService {
  static async importSongs(context: common.UIAbilityContext): Promise<number> {
    const selectOptions = new picker.DocumentSelectOptions();
    selectOptions.maxSelectNumber = 20;
    selectOptions.fileSuffixFilters = [
      '音频 (.mp3, .flac, .m4a, .aac, .wav, .ogg)|.mp3,.flac,.m4a,.aac,.wav,.ogg'
    ];

    const documentPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await documentPicker.select(selectOptions);
    if (!uris || uris.length === 0) {
      return 0;
    }

    const storage = StorageService.getInstance();
    const dir: string = `${context.filesDir}/${LOCAL_DIR_NAME}`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }

    let imported: number = 0;
    for (let i = 0; i < uris.length; i++) {
      const uri: string = uris[i];
      const originalName: string = LocalMusicService.fileNameFromUri(uri);
      if (!LocalMusicService.isAllowed(originalName)) {
        continue;
      }

      const safeName: string = originalName.replace(/[\\/:*?"<>|]/g, '_');
      const destPath: string = `${dir}/track_${Date.now()}_${i}_${safeName}`;
      try {
        const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        try {
          fs.copyFileSync(srcFile.fd, destPath);
        } finally {
          fs.closeSync(srcFile);
        }

        const song: Song = await LocalMusicService.buildSong(destPath, originalName, i);
        await storage.addLocalSong(song);
        imported++;
      } catch (e) {
        console.error('Import local music error:', uri, e);
      }
    }
    return imported;
  }

  static async deleteSong(song: Song): Promise<void> {
    if (song.filePath && fs.accessSync(song.filePath)) {
      try {
        fs.unlinkSync(song.filePath);
      } catch (e) {
        console.error('Delete local file error:', e);
      }
    }
    const storage = StorageService.getInstance();
    await storage.removeLocalSong(song.id);
    await storage.removeFavorite(song.id);
    await storage.removeFromHistory(song.id);
  }

  private static fileNameFromUri(uri: string): string {
    let name: string = uri.substring(uri.lastIndexOf('/') + 1);
    const queryIndex: number = name.indexOf('?');
    if (queryIndex >= 0) {
      name = name.substring(0, queryIndex);
    }
    try {
      name = decodeURIComponent(name);
    } catch (e) {
      // 保留原始文件名
    }
    return name || 'local_track';
  }

  private static isAllowed(fileName: string): boolean {
    const lower: string = fileName.toLowerCase();
    return ALLOWED_EXTENSIONS.some((ext: string) => lower.endsWith(ext));
  }

  private static stripExtension(fileName: string): string {
    const dot: number = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  private static async buildSong(filePath: string, originalName: string, index: number): Promise<Song> {
    let title: string = LocalMusicService.stripExtension(originalName);
    let artist: string = '本地导入';
    let album: string = '本地音乐';
    let duration: number = 0;

    try {
      const extractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(filePath);
        extractor.fdSrc = { fd: file.fd, offset: 0, length: stat.size };
        const metadata: media.AVMetadata = await extractor.fetchMetadata();
        if (metadata.title && metadata.title.length > 0) {
          title = metadata.title;
        }
        if (metadata.artist && metadata.artist.length > 0) {
          artist = metadata.artist;
        } else if (metadata.albumArtist && metadata.albumArtist.length > 0) {
          artist = metadata.albumArtist;
        }
        if (metadata.album && metadata.album.length > 0) {
          album = metadata.album;
        }
        const parsedDuration: number = metadata.duration ? Number(metadata.duration) : 0;
        if (!Number.isNaN(parsedDuration) && parsedDuration > 0) {
          duration = parsedDuration;
        }
      } finally {
        await extractor.release();
        fs.closeSync(file);
      }
    } catch (e) {
      console.error('Read local metadata error:', filePath, e);
    }

    return {
      id: -(Date.now() + index),
      name: title,
      artist,
      album,
      albumId: 0,
      duration,
      url: '',
      coverUrl: '',
      lyric: '',
      filePath
    };
  }
}
