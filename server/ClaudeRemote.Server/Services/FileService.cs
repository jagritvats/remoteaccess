using ClaudeRemote.Server.Models;

namespace ClaudeRemote.Server.Services;

public class FileService
{
    public List<FileEntry> ListDirectory(string path)
    {
        var dir = new DirectoryInfo(path);
        if (!dir.Exists)
            throw new DirectoryNotFoundException($"Directory not found: {path}");

        var entries = new List<FileEntry>();

        foreach (var d in dir.GetDirectories())
        {
            try
            {
                entries.Add(new FileEntry
                {
                    Name = d.Name,
                    Path = d.FullName,
                    IsDirectory = true,
                    Modified = d.LastWriteTime
                });
            }
            catch { /* skip inaccessible dirs */ }
        }

        foreach (var f in dir.GetFiles())
        {
            try
            {
                entries.Add(new FileEntry
                {
                    Name = f.Name,
                    Path = f.FullName,
                    IsDirectory = false,
                    Size = f.Length,
                    Modified = f.LastWriteTime
                });
            }
            catch { /* skip inaccessible files */ }
        }

        return entries;
    }

    public List<FileEntry> GetDrives()
    {
        return DriveInfo.GetDrives()
            .Where(d => d.IsReady)
            .Select(d => new FileEntry
            {
                Name = d.Name,
                Path = d.RootDirectory.FullName,
                IsDirectory = true
            })
            .ToList();
    }

    public async Task<string> ReadTextAsync(string path, int maxBytes = 512_000)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("File not found", path);

        await using var fs = File.OpenRead(path);
        var buffer = new byte[Math.Min(maxBytes, fs.Length)];
        var bytesRead = await fs.ReadAsync(buffer, 0, buffer.Length);
        return System.Text.Encoding.UTF8.GetString(buffer, 0, bytesRead);
    }

    public void CreateDirectory(string path) => Directory.CreateDirectory(path);

    public void Delete(string path)
    {
        if (File.Exists(path))
            File.Delete(path);
        else if (Directory.Exists(path))
            Directory.Delete(path, recursive: true);
    }

    public void Rename(string oldPath, string newPath)
    {
        if (File.Exists(oldPath))
            File.Move(oldPath, newPath);
        else if (Directory.Exists(oldPath))
            Directory.Move(oldPath, newPath);
    }

    public Stream OpenRead(string path) => File.OpenRead(path);

    public async Task SaveUploadAsync(string directory, string fileName, Stream content)
    {
        var fullPath = Path.Combine(directory, fileName);
        await using var fs = File.Create(fullPath);
        await content.CopyToAsync(fs);
    }
}
