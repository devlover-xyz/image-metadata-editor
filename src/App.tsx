// import { useState } from "react";
// import reactLogo from "./assets/react.svg";
// import { invoke } from "@tauri-apps/api/core";
// import "./App.css";

// function App() {
//   const [greetMsg, setGreetMsg] = useState("");
//   const [name, setName] = useState("");

//   async function greet() {
//     // Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
//     setGreetMsg(await invoke("greet", { name }));
//   }

//   return (
//     <main className="container">
//       <h1>Welcome to Tauri + React</h1>

//       <div className="row">
//         <a href="https://vitejs.dev" target="_blank">
//           <img src="/vite.svg" className="logo vite" alt="Vite logo" />
//         </a>
//         <a href="https://tauri.app" target="_blank">
//           <img src="/tauri.svg" className="logo tauri" alt="Tauri logo" />
//         </a>
//         <a href="https://reactjs.org" target="_blank">
//           <img src={reactLogo} className="logo react" alt="React logo" />
//         </a>
//       </div>
//       <p>Click on the Tauri, Vite, and React logos to learn more.</p>

//       <form
//         className="row"
//         onSubmit={(e) => {
//           e.preventDefault();
//           greet();
//         }}
//       >
//         <input
//           id="greet-input"
//           onChange={(e) => setName(e.currentTarget.value)}
//           placeholder="Enter a name..."
//         />
//         <button type="submit">Greet</button>
//       </form>
//       <p>{greetMsg}</p>
//     </main>
//   );
// }

// export default App;


import { useState, useEffect, FormEvent, ChangeEvent } from "react";
import { invoke } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import { AppState, AppStatus, ImageMetadata, PlatformInfo } from "./types/metadata";
import "./App.css";
import { readFile } from "@tauri-apps/plugin-fs";

function App() {
  const [state, setState] = useState<AppState>({
    imagePath: "",
    imagePreview: "",
    metadata: {
      title: "",
      description: "",
      keywords: [],
      date_taken: null,
      author: "",
      copyright: "",
    },
    platformInfo: {
      os: "",
      arch: "",
      family: "",
    },
    status: "idle",
    errorMessage: null,
  });

  useEffect(() => {
    // Dapatkan informasi platform saat komponen dimuat
    const getPlatformInfo = async () => {
      try {
        const info = await invoke<PlatformInfo>("get_platform_info");
        setState(prev => ({
          ...prev,
          platformInfo: info
        }));
      } catch (error) {
        console.error(error);
        setState(prev => ({
          ...prev,
          status: "error",
          errorMessage: `Failed to get platform info: ${error}`
        }));
      }
    };

    getPlatformInfo();
  }, []);

  // Fungsi untuk membuka file gambar
  const openImage = async () => {
    try {
      setState(prev => ({
        ...prev,
        status: "loading"
      }));

      const selected = await open({
        multiple: false,
        filters: [{
          name: "Images",
          extensions: ["jpg", "jpeg", "png", "gif", "tiff", "webp"]
        }]
      });

      if (!selected || Array.isArray(selected)) return;

      const imagePath = selected;
      setState(prev => ({
        ...prev,
        imagePath
      }));

      // Baca file gambar dan tampilkan preview
      const imageBinary = await readFile(imagePath);
      const blob = new Blob([imageBinary.buffer]);
      const url = URL.createObjectURL(blob);

      setState(prev => ({
        ...prev,
        imagePreview: url,
        status: "reading-metadata"
      }));

      // Baca metadata
      const imageMetadata = await invoke<ImageMetadata>("read_metadata", {
        path: imagePath,
      });

      setState(prev => ({
        ...prev,
        metadata: imageMetadata,
        status: "success"
      }));
    } catch (error) {
      console.error(error);
      setState(prev => ({
        ...prev,
        status: "error",
        errorMessage: `Error: ${error}`
      }));
    }
  };

  // Fungsi untuk menyimpan metadata
  const saveMetadata = async () => {
    if (!state.imagePath) {
      setState(prev => ({
        ...prev,
        status: "error",
        errorMessage: "Tidak ada gambar yang dipilih"
      }));
      return;
    }

    try {
      setState(prev => ({
        ...prev,
        status: "saving-metadata"
      }));

      // Panggil fungsi Rust untuk menyimpan metadata
      await invoke("write_metadata", {
        path: state.imagePath,
        metadata: state.metadata,
      });

      setState(prev => ({
        ...prev,
        status: "success",
        errorMessage: null
      }));
    } catch (error) {
      console.error(error);
      setState(prev => ({
        ...prev,
        status: "error",
        errorMessage: `Error: ${error}`
      }));
    }
  };

  const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setState(prev => ({
      ...prev,
      metadata: {
        ...prev.metadata,
        [name]: value
      }
    }));
  };

  const handleKeywordsChange = (e: ChangeEvent<HTMLInputElement>) => {
    const keywordsString = e.target.value;
    const keywords = keywordsString
      .split(",")
      .map(keyword => keyword.trim())
      .filter(keyword => keyword.length > 0);

    setState(prev => ({
      ...prev,
      metadata: {
        ...prev.metadata,
        keywords
      }
    }));
  };

  const getStatusMessage = (status: AppStatus): string => {
    switch (status) {
      case "idle":
        return "Siap";
      case "loading":
        return "Memuat gambar...";
      case "reading-metadata":
        return "Membaca metadata...";
      case "saving-metadata":
        return "Menyimpan metadata...";
      case "success":
        return "Operasi berhasil!";
      case "error":
        return state.errorMessage || "Terjadi kesalahan";
      default:
        return "";
    }
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    saveMetadata();
  };

  return (
    <div className="container">
      <h1>Editor Metadata Gambar</h1>
      <p className="platform-info">
        Platform: {state.platformInfo.os} {state.platformInfo.arch}
      </p>

      <div className="row">
        <div className="column">
          <button type="button" onClick={openImage}>Pilih Gambar</button>
          {state.imagePreview && (
            <div className="image-preview">
              <img src={state.imagePreview} alt="Preview" />
            </div>
          )}
        </div>
        <div className="column">
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label htmlFor="title">Judul:</label>
              <input
                id="title"
                name="title"
                value={state.metadata.title}
                onChange={handleInputChange}
              />
            </div>

            <div className="form-group">
              <label htmlFor="description">Deskripsi:</label>
              <textarea
                id="description"
                name="description"
                value={state.metadata.description}
                onChange={handleInputChange}
                rows={4}
              />
            </div>

            <div className="form-group">
              <label htmlFor="keywords">
                Kata Kunci (pisahkan dengan koma):
              </label>
              <input
                id="keywords"
                name="keywords"
                value={state.metadata.keywords.join(", ")}
                onChange={handleKeywordsChange}
              />
            </div>

            <div className="form-group">
              <label htmlFor="author">Penulis/Fotografer:</label>
              <input
                id="author"
                name="author"
                value={state.metadata.author}
                onChange={handleInputChange}
              />
            </div>

            <div className="form-group">
              <label htmlFor="copyright">Hak Cipta:</label>
              <input
                id="copyright"
                name="copyright"
                value={state.metadata.copyright}
                onChange={handleInputChange}
              />
            </div>

            <div className="form-group">
              <label htmlFor="date_taken">Tanggal Diambil:</label>
              <input
                id="date_taken"
                name="date_taken"
                value={state.metadata.date_taken || ""}
                disabled
                type="text"
              />
              <small>(Hanya baca)</small>
            </div>

            <button type="submit" disabled={state.status === "loading" || state.status === "saving-metadata"}>
              Simpan Metadata
            </button>
          </form>
        </div>
      </div>

      <div className={`status ${state.status === "error" ? "error" : ""}`}>
        {getStatusMessage(state.status)}
      </div>
    </div>
  );
}

export default App;