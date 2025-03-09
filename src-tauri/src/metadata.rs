extern crate rexiv2;

use anyhow::{Context, Result};
use rexiv2::Metadata;
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ImageMetadata {
    pub title: String,
    pub description: String,
    pub keywords: Vec<String>,
    pub date_taken: Option<String>,
    pub author: String,
    pub copyright: String,
}

impl Default for ImageMetadata {
    fn default() -> Self {
        Self {
            title: String::new(),
            description: String::new(),
            keywords: Vec::new(),
            date_taken: None,
            author: String::new(),
            copyright: String::new(),
        }
    }
}

pub fn read_image_metadata(path: &Path) -> Result<ImageMetadata> {
    let metadata = Metadata::new_from_path(path)
        .context(format!("Gagal membaca metadata dari {}", path.display()))?;

    // Coba baca metadata dari berbagai tempat (XMP, IPTC, EXIF)
    let title = metadata
        .get_tag_string("Xmp.dc.title")
        .or_else(|_| metadata.get_tag_string("Iptc.Application2.Headline"))
        .unwrap_or_default();

    let description = metadata
        .get_tag_string("Xmp.dc.description")
        .or_else(|_| metadata.get_tag_string("Iptc.Application2.Caption"))
        .or_else(|_| metadata.get_tag_string("Exif.Image.ImageDescription"))
        .unwrap_or_default();

    let keywords = metadata
        .get_tag_multiple_strings("Xmp.dc.subject")
        .or_else(|_| metadata.get_tag_multiple_strings("Iptc.Application2.Keywords"))
        .unwrap_or_default();

    let date_taken = metadata.get_tag_string("Exif.Photo.DateTimeOriginal").ok();

    let author = metadata
        .get_tag_string("Xmp.dc.creator")
        .or_else(|_| metadata.get_tag_string("Iptc.Application2.Byline"))
        .unwrap_or_default();

    let copyright = metadata
        .get_tag_string("Xmp.dc.rights")
        .or_else(|_| metadata.get_tag_string("Iptc.Application2.Copyright"))
        .unwrap_or_default();

    Ok(ImageMetadata {
        title,
        description,
        keywords,
        date_taken,
        author,
        copyright,
    })
}

pub fn write_image_metadata(path: &Path, metadata: &ImageMetadata) -> Result<()> {
    let rexiv_metadata = Metadata::new_from_path(path)
        .context(format!("Gagal membuka metadata di {}", path.display()))?;

    // Tulis ke format XMP (lebih modern dan luas digunakan)
    if !metadata.title.is_empty() {
        rexiv_metadata.set_tag_string("Xmp.dc.title", &metadata.title)?;
        rexiv_metadata.set_tag_string("Iptc.Application2.Headline", &metadata.title)?;
    }

    if !metadata.description.is_empty() {
        rexiv_metadata.set_tag_string("Xmp.dc.description", &metadata.description)?;
        rexiv_metadata.set_tag_string("Iptc.Application2.Caption", &metadata.description)?;
        rexiv_metadata.set_tag_string("Exif.Image.ImageDescription", &metadata.description)?;
    }

    // Hapus keyword lama dan tulis yang baru
    if !metadata.keywords.is_empty() {
        // Set keywords XMP
        rexiv_metadata.set_tag_multiple_strings(
            "Xmp.dc.subject",
            &metadata
                .keywords
                .iter()
                .map(AsRef::as_ref)
                .collect::<Vec<&str>>(),
        )?;

        // Set keywords IPTC (satu per satu)
        // Pertama hapus yang lama
        if rexiv_metadata.has_tag("Iptc.Application2.Keywords") {
            let _ = rexiv_metadata.clear_tag("Iptc.Application2.Keywords");
        }

        // Tambahkan satu per satu
        for keyword in &metadata.keywords {
            rexiv_metadata.set_tag_string("Iptc.Application2.Keywords", keyword)?;
        }
    }

    if !metadata.author.is_empty() {
        rexiv_metadata.set_tag_string("Xmp.dc.creator", &metadata.author)?;
        rexiv_metadata.set_tag_string("Iptc.Application2.Byline", &metadata.author)?;
    }

    if !metadata.copyright.is_empty() {
        rexiv_metadata.set_tag_string("Xmp.dc.rights", &metadata.copyright)?;
        rexiv_metadata.set_tag_string("Iptc.Application2.Copyright", &metadata.copyright)?;
    }

    // Simpan perubahan
    rexiv_metadata.save_to_file(path)?;

    Ok(())
}

// Fungsi utilitas untuk debugging
pub fn list_all_tags(path: &Path) -> Result<Vec<String>> {
    let metadata = Metadata::new_from_path(path)?;
    let tags = metadata.get_exif_tags()?;
    Ok(tags)
}
