package handler


import (
	"context"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gorilla/mux"
	"github.com/dustin/go-humanize"
)

type DownloadHandler struct {
	S3     *s3.Client
	Bucket string
}

func isInlinePreview(contentType, ext string) bool {
	// 按 Content-Type 判断（最可靠）
	if strings.HasPrefix(contentType, "image/") {
		return true
	}

	switch contentType {
	case "application/pdf",
		"text/plain",
		"text/html",
		"text/css",
		"text/javascript",
		"application/json",
		"application/xml":
		return true
	}

	switch ext {
	case ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg",
		".pdf",
		".txt", ".log", ".md", ".json", ".xml", ".html", ".htm":
		return true
	}

	return false
}

func (h *DownloadHandler) Download(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	object := mux.Vars(r)["object"]
	clientIP := r.RemoteAddr

	log.Printf(
		"DOWNLOAD[BGN] ip=%s object=%s",
		clientIP, object,
	)

	resp, err := h.S3.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: &h.Bucket,
		Key:    &object,
	})
	if err != nil {
		log.Printf(
			"[DOWNLOAD] failed ip=%s object=%s err=%v",
			clientIP, object, err,
		)
		http.Error(w, "object not found", http.StatusNotFound)
		return
	}
	defer resp.Body.Close()

	// -------- Content-Type 自动识别 --------
	ext := strings.ToLower(filepath.Ext(object))
	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	w.Header().Set("Content-Type", contentType)

	// -------- Content-Disposition --------
	inline := isInlinePreview(contentType, ext)
	disposition := "attachment"
	if inline {
		disposition = "inline"
	}
	w.Header().Set(
		"Content-Disposition",
		fmt.Sprintf(`%s; filename="%s"`, disposition, filepath.Base(object)),
	)

	// -------- Content-Length（如果 S3 返回）--------
	if resp.ContentLength != nil && *resp.ContentLength > 0 {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", *resp.ContentLength))
	}

	// -------- 开始传输 --------
	written, err := io.Copy(w, resp.Body)
	if err != nil {
		log.Printf(
			"[DOWNLOAD] stream error ip=%s object=%s err=%v",
			clientIP, object, err,
		)
		return
	}

	log.Printf(
		"DOWNLOAD[END] success object=%s size=%s cost=%vms",
		object,
		humanize.Bytes(uint64(written)),
		time.Since(start).Milliseconds(),
	)
}
