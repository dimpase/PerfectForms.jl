"""CTest checks for the native exporter, independent of Julia and saved caches."""
import json
from fractions import Fraction
from pathlib import Path
import subprocess
import sys
import tempfile


REFERENCES = json.loads(Path(__file__).with_name('reference_cases.json').read_text())


def namelist(discriminant, dimension=2):
    root_sum = discriminant % 4 if discriminant != 1 else 0
    root_product = (root_sum - discriminant) // 4 if discriminant != 1 else 0
    kind = 'Classic' if discriminant == 1 else 'RealQuad' if discriminant > 0 else 'ImagQuad'
    comm = 'Trivial' if discriminant == 1 else 'Use_realimag'
    return f'''&TSPACE
  TypeTspace = "{kind}"
  ClassicDim = {dimension}
  RealImagDim = {dimension}
  RealImagSum = {root_sum}
  RealImagProd = {root_product}
  SuperMatMethod = "NotNeeded"
  ListComm = "{comm}"
  PtGroupMethod = "Trivial"
  FileListSubspaces = "unset"
/
&DATA
  arithmetic = "gmp"
  OnlyWellRounded = T
  ComputeComplex = F
  ComputeBoundary = F
  ComputePreImage = F
  CacheFile = "none"
/
'''


def determinant(matrix):
    a = [[Fraction(x) for x in row] for row in matrix]
    result = Fraction(1)
    for i in range(len(a)):
        pivot = next((j for j in range(i, len(a)) if a[j][i]), None)
        if pivot is None:
            return Fraction(0)
        if pivot != i:
            a[i], a[pivot] = a[pivot], a[i]
            result = -result
        value = a[i][i]
        result *= value
        for j in range(i + 1, len(a)):
            scale = a[j][i] / value
            a[j] = [x - scale * y for x, y in zip(a[j], a[i])]
    return result


def quadratic(matrix, vector):
    return sum(Fraction(x) * vector[i] * vector[j]
               for i, row in enumerate(matrix) for j, x in enumerate(row))


def check(binary, case, folder):
    name = 'classical2' if case in ('rejection', 'raw_classical2', 'default_forms_only') else case
    reference = next(c for c in REFERENCES['cases'] if c['name'] == name)
    text = namelist(reference['discriminant'], reference['dimension'])
    if case == 'default_forms_only':
        text = text.replace('  ComputeComplex = F\n', '')
    if case == 'raw_classical2':
        basis = folder / 'basis with spaces.txt'
        basis.write_text('3\n2 2\n1 0\n0 0\n2 2\n0 1\n1 0\n2 2\n0 0\n0 1\n')
        text = text.replace('TypeTspace = "Classic"', 'TypeTspace = "Raw"')
        text = text.replace('SuperMatMethod = "NotNeeded"', 'SuperMatMethod = "Compute"')
        text = text.replace('&TSPACE\n', f'&TSPACE\n  FileListMat = "{basis}"\n')
    if case == 'rejection':
        text = text.replace('ComputeBoundary = F', 'ComputeBoundary = T')
    source, output = folder / 'input.nml', folder / 'output.json'
    source.write_text(text)
    token = 'a' * 64
    result = subprocess.run([binary, str(source), str(output), token],
                            cwd=folder, capture_output=True, text=True, timeout=160)
    if case == 'rejection':
        assert result.returncode == 64, result.stderr
        assert not output.exists(), 'Rejected operation produced an output file'
        errors = [json.loads(line[len('AV_ERROR '):]) for line in result.stderr.splitlines()
                  if line.startswith('AV_ERROR ')]
        assert errors[-1]['code'] == 'unsupported_operation', errors
        return
    assert result.returncode == 0, result.stderr
    data = json.loads(output.read_text())
    assert data['schema'] == 'av_polyhedral_export_v1'
    assert data['request_token'] == token and data['completed'] is True
    assert data['pending_facets'] == []
    representatives = data['representatives']
    expected = reference['orbits']
    assert len(representatives) == expected, (len(representatives), expected)
    assert data['lattice_dimension'] == reference['lattice_dimension']
    assert data['form_space_dimension'] == reference['form_space_dimension']
    assert len(data['form_basis']) == reference['form_space_dimension']
    determinants, ray_counts = [], []
    for representative in representatives:
        gram = representative['gram']
        dimension = len(gram)
        assert dimension == reference['lattice_dimension']
        assert all(len(row) == dimension for row in gram)
        assert all(gram[i][j] == gram[j][i] for i in range(dimension) for j in range(dimension))
        assert all(determinant([row[:k] for row in gram[:k]]) > 0 for k in range(1, dimension + 1))
        minimum = Fraction(representative['minimum'])
        vectors = [tuple(int(x) for x in row) for row in representative['minimal_vectors']]
        assert len(vectors) == len(set(vectors))
        assert all(tuple(-x for x in v) in set(vectors) for v in vectors)
        assert all(quadratic(gram, v) == minimum for v in vectors)
        determinants.append(determinant(gram) / minimum**dimension)
        ray_counts.append(len({tuple(quadratic(b, v) for b in data['form_basis']) for v in vectors}))
        assert int(representative['stabilizer_order']) > 0
        assert representative['stabilizer_generators_row']
        assert representative['neighbours']
        for neighbour in representative['neighbours']:
            assert 1 <= neighbour['target'] <= expected
            assert neighbour['facet_vector_indices_zero_based']
            assert neighbour['transporter_row']
    for key, actual in (
            ('minimal_vector_counts', [len(r['minimal_vectors']) for r in representatives]),
            ('stabilizer_orders', [int(r['stabilizer_order']) for r in representatives]),
            ('normalized_determinants', determinants),
            ('evaluation_ray_counts', ray_counts)):
        if key in reference:
            expected_values = [Fraction(x) for x in reference[key]]
            assert sorted(actual) == sorted(expected_values), (key, actual, expected_values)
    progress = [json.loads(line) for line in
                Path(str(output) + '.progress.jsonl').read_text().splitlines()]
    assert len(progress) == expected and progress[-1]['completed_objects'] == expected
    print(f'{case}: {expected} completed perfect-form orbits; {reference["reference"]} reference matched')


if __name__ == '__main__':
    binary = str(Path(sys.argv[1]).resolve())
    # Spaces also exercise the argument-based CLI used by the Julia adapter.
    with tempfile.TemporaryDirectory(prefix='av backend smoke ') as temporary:
        check(binary, sys.argv[2], Path(temporary))
