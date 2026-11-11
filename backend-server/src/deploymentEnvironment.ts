const productionProject = 'lpbdxtzyzlaioggefscc';

export function validateBackendEnvironment(env: NodeJS.ProcessEnv): void {
  const mode = (env.CHEKMI_ENV || (env.NODE_ENV === 'production' ? 'production' : 'development')).toLowerCase();
  if (!['development', 'staging', 'production'].includes(mode)) {
    throw new Error('CHEKMI_ENV must be development, staging, or production.');
  }
  if (mode === 'development') return;
  const project = mode === 'production' ? productionProject : env.CHEKMI_STAGING_PROJECT_REF;
  if (!project || (mode === 'staging' && (project === productionProject || !/^[a-z0-9]{20}$/.test(project)))) {
    throw new Error('A distinct CHEKMI_STAGING_PROJECT_REF is required in staging.');
  }
  if (env.SUPABASE_URL?.replace(/\/$/, '') !== `https://${project}.supabase.co`) {
    throw new Error(`SUPABASE_URL does not match the ${mode} project.`);
  }
  if (!env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY is required.');
  }
}
