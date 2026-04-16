package handler

import (
    "archive/zip"
    "context"
    "encoding/json"
    "io"
    "net/http"
     "fmt"

    "github.com/aws/aws-sdk-go-v2/service/s3"
)

type ZipDownloadHandler struct {
    S3     *s3.Client
    Bucket string
}

type ZipRequest struct {
    Files   []string `json:"files"`
    ZipName string   `json:"zip_name"`
}

func (h *ZipDownloadHandler) DownloadZip(w http.ResponseWriter, r *http.Request) {
    var req ZipRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    if len(req.Files) == 0 {
        http.Error(w, "files empty", http.StatusBadRequest)
        return
    }

    zipName := req.ZipName
    if zipName == "" {
        zipName = "download.zip"
    }

    w.Header().Set("Content-Type", "application/zip")
    w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, zipName))

    zipWriter := zip.NewWriter(w)
    defer zipWriter.Close()

    for _, object := range req.Files {
        resp, err := h.S3.GetObject(context.TODO(), &s3.GetObjectInput{
            Bucket: &h.Bucket,
            Key:    &object,
        })
        if err != nil {
            http.Error(w, "failed: "+object, http.StatusNotFound)
            return
        }

        func() {
            defer resp.Body.Close()
            f, _ := zipWriter.Create(object)
            io.Copy(f, resp.Body)
        }()
    }
}
