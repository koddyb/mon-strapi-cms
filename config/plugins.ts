import type { Core } from '@strapi/strapi';

const allowedMediaTypes = [
  'image/*',
  'video/*',
  'audio/*',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.*',
  'text/plain',
  'text/csv',
];

const deniedTypes = [
  'image/svg+xml',
  'application/vnd.microsoft.portable-executable',
  'application/x-msdownload',
  'application/x-msdos-program',
  'application/x-executable',
  'application/x-dosexec',
  'application/x-sh',
  'text/x-shellscript',
  'application/x-mach-binary',
];

const config = ({ env }: Core.Config.Shared.ConfigParams): Core.Config.Plugin => {
  // Le filesystem d'un dyno Heroku est ephemere : tout fichier ecrit dans
  // public/uploads disparait au prochain redemarrage (deploiement, restart
  // quotidien, scaling). En production les medias doivent donc partir chez un
  // provider externe ; en developpement on garde le provider local pour ne
  // dependre d'aucun service tiers.
  const isProduction = env('NODE_ENV') === 'production';

  const uploadProvider = isProduction
    ? {
        provider: 'cloudinary',
        providerOptions: {
          cloud_name: env('CLOUDINARY_NAME'),
          api_key: env('CLOUDINARY_KEY'),
          api_secret: env('CLOUDINARY_SECRET'),
        },
        actionOptions: {
          upload: {},
          uploadStream: {},
          delete: {},
        },
      }
    : {
        provider: 'local',
      };

  return {
    'users-permissions': {
      config: {
        jwtManagement: 'refresh',
        sessions: {
          httpOnly: true,
        },
      },
    },
    upload: {
      config: {
        ...uploadProvider,
        security: {
          allowedTypes: allowedMediaTypes,
          deniedTypes,
        },
      },
    },
  };
};

export default config;
