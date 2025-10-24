# Copyright (c) 2019, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:24.04 as builder

ARG GOLANG_VERSION=1.20
ENV GOLANG_VERSION=${GOLANG_VERSION}

RUN apt-get update && \
    apt-get install -y --no-install-recommends golang-${GOLANG_VERSION} && \
    apt-get clean
ENV PATH=/usr/lib/go-${GOLANG_VERSION}/bin:${PATH}

WORKDIR /work
COPY src/. .
RUN go build -o vgpu-util

FROM ubuntu:24.04
COPY --from=builder /work/vgpu-util /usr/local/bin/vgpu-util
ARG VERSION

ENTRYPOINT ["/usr/bin/sleep", "infinity"]
