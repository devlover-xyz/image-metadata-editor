/**
 * Interface yang mewakili metadata gambar
 */
export interface ImageMetadata {
    title: string;
    description: string;
    keywords: string[];
    date_taken: string | null;
    author: string;
    copyright: string;
}

/**
 * Interface untuk informasi platform
 */
export interface PlatformInfo {
    os: string;
    arch: string;
    family: string;
}

/**
 * Status aplikasi untuk pelacakan state
 */
export type AppStatus =
    | 'idle'
    | 'loading'
    | 'reading-metadata'
    | 'saving-metadata'
    | 'success'
    | 'error';

/**
 * State aplikasi
 */
export interface AppState {
    imagePath: string;
    imagePreview: string;
    metadata: ImageMetadata;
    platformInfo: PlatformInfo;
    status: AppStatus;
    errorMessage: string | null;
}