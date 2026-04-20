@echo off

set SRC=D:\CSNP
set DST=D:\CSNP\csnp-zngtfy-profile\CLAUDE

copy /Y "%SRC%\GitOps\csnp-gitops_docker\CLAUDE.md" "%DST%\csnp-gitops_docker-CLAUDE.md"
copy /Y "%SRC%\GitOps\csnp-gitops_kubernetes\CLAUDE.md" "%DST%\csnp-gitops_kubernetes-CLAUDE.md"
copy /Y "%SRC%\Presentation\csnp-admin\CLAUDE.md" "%DST%\csnp-admin-CLAUDE.md"
copy /Y "%SRC%\Application\csnp-compliance\CLAUDE.md" "%DST%\csnp-compliance-CLAUDE.md"
copy /Y "%SRC%\Docs\csnp-docs\CLAUDE.md" "%DST%\csnp-docs-CLAUDE.md"
copy /Y "%SRC%\Application\csnp-fintech\CLAUDE.md" "%DST%\csnp-fintech-CLAUDE.md"
copy /Y "%SRC%\InfraOps\csnp-infra\CLAUDE.md" "%DST%\csnp-infra-CLAUDE.md"
copy /Y "%SRC%\Application\csnp-platform\CLAUDE.md" "%DST%\csnp-platform-CLAUDE.md"
copy /Y "%SRC%\Presentation\csnp-web\CLAUDE.md" "%DST%\csnp-web-CLAUDE.md"