using CloudinaryDotNet;
using CloudinaryDotNet.Actions;

namespace TFMS_software_api.Services;

public interface ICloudinaryService
{
    Task<string?> UploadFileAsync(IFormFile file, string folder);
}

public class CloudinaryService : ICloudinaryService
{
    private readonly Cloudinary _cloudinary;

    public CloudinaryService(IConfiguration config)
    {
        var account = new Account(
            config["Cloudinary:CloudName"],
            config["Cloudinary:ApiKey"],
            config["Cloudinary:ApiSecret"]
        );
        _cloudinary = new Cloudinary(account);
        _cloudinary.Api.Secure = true;
    }

    public async Task<string?> UploadFileAsync(IFormFile file, string folder)
    {
        if (file == null || file.Length == 0) return null;

        await using var stream = file.OpenReadStream();

        var ext   = Path.GetExtension(file.FileName).ToLowerInvariant();
        var isPdf = ext == ".pdf";

        // All files go under TFMS_Software/<folder>
        var cloudFolder = $"TFMS_Software/{folder}";

        if (isPdf)
        {
            var uploadParams = new RawUploadParams
            {
                File           = new FileDescription(file.FileName, stream),
                Folder         = cloudFolder,
                UseFilename    = false,
                UniqueFilename = true,
            };
            var result = await _cloudinary.UploadAsync(uploadParams);
            return result?.SecureUrl?.ToString();
        }
        else
        {
            var uploadParams = new ImageUploadParams
            {
                File           = new FileDescription(file.FileName, stream),
                Folder         = cloudFolder,
                UseFilename    = false,
                UniqueFilename = true,
            };
            var result = await _cloudinary.UploadAsync(uploadParams);
            return result?.SecureUrl?.ToString();
        }
    }
}
